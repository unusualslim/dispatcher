# The FPST journal for one source document's inventory movements on one date (a PO's receipt, a PDI
# order's sale, an adjustment, a PDI sync, a revaluation). Each movement posts its value to the
# location's Inventory account against the movement's offset, all at Site-Major-Sub:
#
#   receipt              Dr Inventory (book value), Dr/Cr PPV (variance), Cr Received not invoiced (actual)
#   sale                 Dr COGS, Cr Inventory
#   adjustment, pdi_sync Inventory against Inventory adjustments
#   revaluation          Inventory against Revaluation
#
# Reversals post the mirror image. Lines are summed by account.
class InventoryJournal
  OFFSET_ROLES = { 'receipt' => 'receipts_clearing', 'sale' => 'cogs', 'adjustment' => 'adjustment',
                   'pdi_sync' => 'adjustment', 'revaluation' => 'revaluation' }.freeze

  Line = Struct.new(:account, :description, :debit, :credit, keyword_init: true)

  attr_reader :moves, :reference_date

  def initialize(moves, reference_date)
    @moves = moves
    @reference_date = reference_date
  end

  def journal_id = ProductionOrderJournal::JOURNAL_ID

  def source
    moves.first.transactable
  end

  def description
    first = moves.first
    "#{first.movement_type_label} #{first.reference_number}".strip.first(50)
  end

  def lines
    @lines ||= amounts.filter_map do |(account, label), amount|
      next if amount.zero?

      Line.new(account: account, description: label.first(50), debit: (amount if amount.positive?),
               credit: (-amount if amount.negative?))
    end
  end

  # Accounts or sites that are missing; nothing posts until they're filled in.
  def problems
    moves.flat_map { |move| legs(move).filter_map { |role, _| missing(move, role) } }.uniq
  end

  def ready?
    problems.empty?
  end

  private

  # { [full account, line description] => signed amount (debit positive) }
  def amounts
    moves.each_with_object(Hash.new(0.to_d)) do |move, sums|
      group = move.product.reporting_group
      legs(move).each do |role, amount|
        sums[[account(move, role), "#{ReportingGroup::INVENTORY_ACCOUNTS[role]} #{group.name}"]] += amount
      end
    end
  end

  # [[role, signed amount]] for one movement; balanced, in cents.
  def legs(move)
    inventory = move.signed_value.to_d.round(2)
    ppv = move.movement_type == 'receipt' ? move.variance_amount.to_d.round(2) : 0
    offset = [OFFSET_ROLES.fetch(move.movement_type), -(inventory + ppv)]
    [['inventory', inventory], (['ppv', ppv] unless ppv.zero?), offset].compact
  end

  def account(move, role)
    "#{move.location.pdi_site_code}-#{move.product.reporting_group.inventory_account(role)}"
  end

  def missing(move, role)
    group = move.product.reporting_group
    return "#{move.location.company_name} has no PDI site code" if move.location.pdi_site_code.blank?

    "#{group.name} has no #{ReportingGroup::INVENTORY_ACCOUNTS[role]} account" if group.inventory_account(role).blank?
  end
end
