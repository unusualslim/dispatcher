class PurchaseOrderLineItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :product, optional: true
  # Expense PO lines: a description (product_name), the GL expense account, the equipment it's for and the
  # site it belongs to (the GL site segment).
  belongs_to :expense_account, optional: true
  belongs_to :equipment, class_name: 'Thing', optional: true, inverse_of: :expense_lines
  belongs_to :location, optional: true

  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true

  def total_cost
    return nil if quantity.nil? || unit_cost.nil?

    quantity * unit_cost
  end

  def display_name
    product&.name || product_name || product_id || 'Unknown Product'
  end

  # Site-Major-Sub, as AP keys it into PDI (blank parts left out until they're set).
  def gl_account_code
    [location&.pdi_site_code.presence, expense_account&.account].compact.join('-').presence
  end
end
