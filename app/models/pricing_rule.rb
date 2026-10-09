class PricingRule < ApplicationRecord
  belongs_to :customer, optional: true
  has_many :pricing_rule_products, dependent: :destroy
  has_many :products, through: :pricing_rule_products

  BASES   = %w[standard_cost inventory_cost standard_calculated].freeze
  METHODS = %w[markup margin flat].freeze

  validates :name,           presence: true
  validates :pricing_basis,  inclusion: { in: BASES }
  validates :pricing_method, inclusion: { in: METHODS }
  validates :value,          presence: true, numericality: { greater_than_or_equal_to: 0 }

  def active?(date = Date.today)
    (effective_date.nil? || effective_date <= date) &&
      (expiration_date.nil? || expiration_date >= date)
  end

  # Calculate the sell price for a given product under this rule.
  def calculated_price(product)
    basis = case pricing_basis
            when 'standard_cost'      then product.cost_per_unit.to_d
            when 'inventory_cost'     then product.cost_per_unit.to_d
            when 'standard_calculated' then bom_cost(product)
            end

    return nil if basis.nil? || basis == 0

    case pricing_method
    when 'markup' then (basis * (1 + value / 100)).round(4)
    when 'margin' then value >= 100 ? nil : (basis / (1 - value / 100)).round(4)
    when 'flat'   then value.to_d
    end
  end

  def pricing_method_label
    { 'markup' => 'Markup %', 'margin' => 'Margin %', 'flat' => 'Flat $ / unit' }[pricing_method]
  end

  def pricing_basis_label
    { 'standard_cost' => 'Standard Cost', 'inventory_cost' => 'Inventory Cost',
      'standard_calculated' => 'Standard Calculated (BOM)' }[pricing_basis]
  end

  private

  def bom_cost(product)
    product.product_components.includes(:component_product).sum do |pc|
      (pc.component_product&.cost_per_unit || 0).to_d * pc.quantity_per_unit.to_d
    end
  end
end
