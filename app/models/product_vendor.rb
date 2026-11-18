class ProductVendor < ApplicationRecord
  belongs_to :product
  belongs_to :vendor
  has_many :prices, -> { ordered }, class_name: 'VendorItemPrice', dependent: :destroy, inverse_of: :product_vendor
  validates :priority, presence: true, numericality: { only_integer: true, greater_than: 0 }
  validates :vendor_id, uniqueness: { scope: :product_id }
end
