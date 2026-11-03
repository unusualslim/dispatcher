# Expense POs: parts and supplies charged straight to GL expense accounts (e.g. packaging equipment parts),
# as opposed to inventory POs whose products go into stock. Expense POs are tracked in the app only: never sent
# to PDI or posted to inventory; AP keys the vendor bill into PDI against each line's Site-Major-Sub account.
module PurchaseOrderExpense
  extend ActiveSupport::Concern

  PO_TYPES = { 'inventory' => 'Inventory', 'expense' => 'Expense' }.freeze

  included do
    validates :po_type, inclusion: { in: PO_TYPES.keys }
    validate :expense_lines_described, if: :expense?
    before_validation :prepare_expense_lines, if: :expense?

    scope :inventory_type, -> { where(po_type: 'inventory') }
    scope :expense,        -> { where(po_type: 'expense') }
  end

  def expense?
    po_type == 'expense'
  end

  def po_type_label
    PO_TYPES[po_type]
  end

  # What has to be fixed before approval: every expense line needs a GL account and a site.
  def approval_problems
    return [] unless expense?

    lines = current_lines
    return ['Add at least one line'] if lines.empty?

    lines.filter_map do |line|
      missing = [('GL account' unless line.expense_account), ('site' unless line.location)].compact
      "#{line.product_name}: needs a #{missing.join(' and ')}" if missing.any?
    end
  end

  private

  def current_lines
    line_items.reject(&:marked_for_destruction?)
  end

  # Expense lines carry no product. A line's site defaults to its equipment's location, then the PO's ship-to.
  def prepare_expense_lines
    line_items.each do |line|
      line.product_id = nil
      line.location ||= line.equipment&.location || location
    end
  end

  def expense_lines_described
    errors.add(:base, :expense_line_description) if current_lines.any? { |line| line.product_name.blank? }
  end
end
