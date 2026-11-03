# Equipment & Assets: trucks and trailers (assigned to dispatches) and equipment such as packaging lines,
# which expense PO lines can be charged to.
class Thing < ApplicationRecord
  CATEGORIES = { 'truck' => 'Truck', 'trailer' => 'Trailer', 'equipment' => 'Equipment' }.freeze

  belongs_to :dispatches, optional: true
  belongs_to :location, optional: true
  has_many :work_orders, as: :workable, dependent: :destroy
  has_many :expense_lines, class_name: 'PurchaseOrderLineItem', foreign_key: :equipment_id,
                           inverse_of: :equipment, dependent: :restrict_with_error

  validates :category, inclusion: { in: CATEGORIES.keys, message: '%{value} is not a valid category' }

  scope :equipment, -> { where(category: 'equipment').order(:name) }
end
