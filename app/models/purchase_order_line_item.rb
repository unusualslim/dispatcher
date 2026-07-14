class PurchaseOrderLineItem < ApplicationRecord
  belongs_to :purchase_order
  belongs_to :product, optional: true

  validates :quantity, numericality: { greater_than: 0 }, allow_nil: true

  def total_cost
    return nil if quantity.nil? || unit_cost.nil?
    quantity * unit_cost
  end

  def display_name
    product&.name || product_name || product_id || 'Unknown Product'
  end
end
