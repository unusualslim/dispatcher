# An approved substitute for an item: what can be used in its place (ratio = substitute units per unit of the item),
# in order of preference. Kept on the item's product page; production shortages show the substitutes' stock.
class ProductSubstitute < ApplicationRecord
  include Audited

  audited

  belongs_to :product
  belongs_to :substitute, class_name: 'Product'

  validates :substitute_id, uniqueness: { scope: :product_id }
  validates :ratio, numericality: { greater_than: 0 }
  validate :not_itself

  scope :ordered, -> { order(:priority, :id) }

  private

  def not_itself
    errors.add(:substitute, "can't be the item itself") if substitute_id == product_id
  end
end
