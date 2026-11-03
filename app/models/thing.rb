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
  # Dispatch pickers only ever list these, never equipment.
  scope :trucks,    -> { where(category: 'truck').order(:name) }
  scope :trailers,  -> { where(category: 'trailer').order(:name) }
  scope :vehicles,  -> { where(category: %w[truck trailer]).order(:category, :name) }

  # Name plus serial number, for pickers and the vendor copy of a PO.
  def label
    serial_number.present? ? "#{name} (S/N #{serial_number})" : name
  end
end
