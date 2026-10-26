# PDI carriers (master data Carrier ERPNumber = the CarrierID on PDI orders), synced by the PDI Master Data
# import so imported orders can show the carrier's name.
class PdiCarrier < ApplicationRecord
  validates :pdi_carrier_id, presence: true, uniqueness: true
  validates :name, presence: true

  def self.name_for(pdi_carrier_id)
    find_by(pdi_carrier_id: pdi_carrier_id)&.name
  end
end
