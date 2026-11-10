# A PDI fuel load (GetFuelLoads, imported by PdiFuelLoads::Import). items = its purchase freight: one per load
# line ({order_no, bol, product, quantity, rate, amount}, zero lines kept as on PDI's FI Fuel Delivery Report)
# and one per per-load charge ({charge, amount}).
class PdiFuelLoad < ApplicationRecord
  validates :load_no, presence: true, uniqueness: true
  validates :business_date, presence: true

  scope :containing_orders, ->(order_nos) { where('order_nos && ARRAY[?]::varchar[]', order_nos) }

  def label
    [load_no, load_reference_no].compact_blank.join(' / ')
  end
end
