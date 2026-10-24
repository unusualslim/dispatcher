class LedgerLine < ApplicationRecord
  belongs_to :ledger_entry

  validates :account, :line_description, presence: true
  validate :debit_or_credit

  # PdiGlImport reads lines through `description`.
  def description
    line_description
  end

  private

  def debit_or_credit
    errors.add(:base, 'needs a debit or a credit, not both') unless debit.present? ^ credit.present?
  end
end
