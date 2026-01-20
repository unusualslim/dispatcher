class ProductComponent < ApplicationRecord
  belongs_to :product
  belongs_to :component_product, class_name: "Product"

  validates :quantity_per_unit, numericality: { greater_than: 0 }, allow_nil: false
end
