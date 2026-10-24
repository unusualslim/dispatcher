# The FPST journal entry for one production order: clears the PDI repack fee against
# the absorbed costs from ProductionOrderCosting, with the remainder to variance.
#
#   Dr repack clearing   fee × qty
#      Cr each consumables / overhead cost line at standard, to its reporting group's account
#      Cr line labor at actual to the labor group, one line per employment type
#      Dr/Cr variance    whatever balances the entry
#
# Accounts are Site-Major-Sub: the site is the production location's PDI site number and
# Major-Sub comes from the reporting group (clearing and variance from Costing Settings).
# Preview only until the ledger exists.
class ProductionOrderJournal
  JOURNAL_ID = 'FPST'.freeze

  # Accounts not tied to a reporting group; Major-Sub lives in AppSetting under "gl_account.<role>".
  ACCOUNT_ROLES = {
    'repack_clearing' => 'Repack fee clearing',
    'variance' => 'Production variance'
  }.freeze

  # posting: what the line is for (reporting group or role label), shown beside the account.
  Line = Struct.new(:posting, :description, :debit, :credit, :account, keyword_init: true)

  def self.account_for(role)
    AppSetting.get("gl_account.#{role}").presence
  end

  attr_reader :production_order, :costing

  def initialize(production_order, costing: ProductionOrderCosting.new(production_order))
    @production_order = production_order
    @costing = costing
  end

  def reference_number
    production_order.number
  end

  def reference_date
    production_order.date_completed
  end

  def journal_id = JOURNAL_ID

  def description
    "Prod #{production_order.number} #{costing.product&.name}".strip.first(50)
  end

  def site_code
    production_order.location&.pdi_site_code
  end

  def lines
    @lines ||= build_lines
  end

  def total_debits
    lines.sum(0.to_d) { |l| l.debit.to_d }
  end

  def total_credits
    lines.sum(0.to_d) { |l| l.credit.to_d }
  end

  # Reasons the entry can't be exported yet (empty when ready).
  def problems
    costing_problems + posting_problems + unmapped_account_problems
  end

  def ready?
    problems.empty?
  end

  def full_account(major_sub)
    return nil unless major_sub && site_code

    "#{site_code}-#{major_sub}"
  end

  private

  # Cost lines always show (it's the order's costing); clearing and variance need the repack fee
  # and a quantity produced.
  def build_lines
    credits = (standard_credits + labor_credits).reject { |l| l.credit.zero? }
    return credits unless costing.repack_fee_applied&.positive?

    clearing = role_line('repack_clearing', 'Clear PDI repack fee', debit: costing.repack_fee_applied)
    [clearing, *credits, variance_line(clearing, credits)].compact
  end

  NO_QUANTITY = 'No quantity produced: enter Total Qty Produced on the order (Edit) or add a batch'.freeze

  def costing_problems
    return ['No product linked'] unless costing.product

    [(NO_QUANTITY unless costing.qty_produced.positive?),
     ('Product has no PDI repack fee' unless costing.repack_fee_applied)].compact
  end

  def posting_problems
    [('Production order is voided' if production_order.voided?),
     ('Not completed (no completion date)' unless reference_date),
     ('Production location has no PDI site number' unless site_code)].compact
  end

  def standard_credits
    costing.non_labor_lines.map do |cl|
      group = cl.reporting_group
      line(group.name, "#{cl.description} (std)", group.gl_account, credit: cl.standard)
    end
  end

  def labor_credits
    group = costing.labor_group
    costing.actual_labor_hours_by_type.sort.map do |type, hours|
      line("#{group&.name || 'Labor'} (#{User::EMPLOYMENT_TYPES[type]})",
           "Line labor #{User::EMPLOYMENT_TYPES[type]} #{hours.round(2)} hrs",
           group&.account_for_employment(type), credit: hours * costing.labor_rate)
    end
  end

  def unmapped_account_problems
    unmapped = lines.reject(&:account).map(&:posting).uniq
    unmapped.any? ? ["No GL account set for: #{unmapped.join(', ')}"] : []
  end

  def variance_line(clearing, credits)
    remaining = clearing.debit - credits.sum(0.to_d, &:credit)
    return nil if remaining.zero?

    if remaining.positive?
      role_line('variance', 'Production variance (favorable)', credit: remaining)
    else
      role_line('variance', 'Production variance (unfavorable)', debit: -remaining)
    end
  end

  def role_line(role, description, **amounts)
    line(ACCOUNT_ROLES[role], description, self.class.account_for(role), **amounts)
  end

  # Amounts are rounded to cents per line so the variance plug keeps the entry balanced.
  def line(posting, description, account, debit: nil, credit: nil)
    Line.new(posting: posting, description: description, debit: debit&.round(2), credit: credit&.round(2),
             account: account)
  end
end
