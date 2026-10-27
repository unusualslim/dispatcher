# A posted GL journal entry. Lines are frozen at posting; corrections are reversing entries,
# never edits. Approved entries wait for the FPST export to PDI, which marks them exported.
class LedgerEntry < ApplicationRecord
  STATUSES = %w[approved exported].freeze

  belongs_to :production_order, optional: true
  # Inventory entries: the PO, PDI order, product… whose movements they post (InventoryGlPosting).
  belongs_to :source, polymorphic: true, optional: true
  has_many :inventory_transactions, dependent: :nullify
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :sync_log, optional: true
  belongs_to :reversal_of, class_name: 'LedgerEntry', optional: true
  has_one :reversal, class_name: 'LedgerEntry', foreign_key: :reversal_of_id, inverse_of: :reversal_of,
                     dependent: :restrict_with_error
  has_many :ledger_lines, -> { order(:position) }, dependent: :destroy, inverse_of: :ledger_entry

  validates :reference_number, presence: true, uniqueness: true, length: { maximum: 30 }
  validates :description, presence: true, length: { maximum: 50 }
  validates :reference_date, :journal_id, :approved_at, presence: true
  validates :status, inclusion: { in: STATUSES }
  validate :balanced

  scope :pending_export, -> { where(status: 'approved') }
  scope :newest_first, -> { order(approved_at: :desc, id: :desc) }

  # Freezes a ready ProductionOrderJournal into a posted entry.
  def self.post!(journal, user)
    raise ArgumentError, "Not ready to post: #{journal.problems.join('; ')}" unless journal.ready?

    order = journal.production_order
    order.with_lock do
      raise ArgumentError, 'This production order already has a posted entry' if active_for(order)

      create!(production_order: order, reference_number: next_reference(order), reference_date: journal.reference_date,
              description: journal.description, journal_id: journal.journal_id, approved_by: user,
              approved_at: Time.current, ledger_lines: lines_from(journal))
    end
  end

  # The entry currently in force for a production order (posted and not reversed).
  def self.active_for(order)
    where(production_order: order, reversal_of_id: nil).where.missing(:reversal).first
  end

  def self.next_reference(order)
    count = where(production_order: order, reversal_of_id: nil).count
    count.zero? ? order.number : "#{order.number}-#{count + 1}"
  end

  def self.lines_from(journal)
    journal.lines.each_with_index.map do |l, i|
      LedgerLine.new(position: i + 1, posting: l.posting, account: journal.full_account(l.account),
                     line_description: l.description.first(50), debit: l.debit, credit: l.credit)
    end
  end

  # Posts the mirror image (debits ↔ credits) dated today, so it lands in the open period.
  def reverse!(user)
    raise ArgumentError, 'Reversing entries cannot be reversed' if reversal_of
    raise ArgumentError, 'Already reversed' if reversal

    LedgerEntry.create!(
      production_order: production_order, source: source, reversal_of: self,
      reference_number: "#{reference_number}-REV",
      reference_date: Time.zone.today, description: "Reverse #{description}".first(50), journal_id: journal_id,
      approved_by: user, approved_at: Time.current, ledger_lines: reversed_lines
    )
  end

  def reversed_lines
    ledger_lines.map do |l|
      LedgerLine.new(position: l.position, posting: l.posting, account: l.account, debit: l.credit, credit: l.debit,
                     line_description: "REV #{l.line_description}".first(50))
    end
  end

  def exported?
    status == 'exported'
  end

  def reversed?
    reversal.present?
  end

  # PdiGlImport interface: accounts are stored complete.
  def lines
    ledger_lines
  end

  def full_account(account)
    account
  end

  def total_debits
    ledger_lines.sum { |l| l.debit.to_d }
  end

  def total_credits
    ledger_lines.sum { |l| l.credit.to_d }
  end

  private

  def balanced
    errors.add(:base, 'Entry has no lines') if ledger_lines.empty?
    errors.add(:base, 'Debits and credits must balance') unless total_debits == total_credits
  end
end
