class ProductionOrderComponent < ApplicationRecord
  belongs_to :production_order
  belongs_to :product, optional: true

  before_validation :default_position

  private

  def default_position
    self.position ||= 9999
  end
end
