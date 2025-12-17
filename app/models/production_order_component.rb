class ProductionOrderComponent < ApplicationRecord
  belongs_to :production_order

  before_validation :default_position

  private

  def default_position
    self.position ||= 9999
  end
end
