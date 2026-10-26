module PdiMasterData
  # PDI carriers → pdi_carriers (ERPNumber = the CarrierID on PDI orders; 1514 = Five Points Logistics).
  class CarrierSync < Sync
    SECTION = :carriers

    def call
      @existing = PdiCarrier.all.index_by(&:pdi_carrier_id)
      @doc.xpath('//Carriers/Carrier').each do |node|
        id = text(node, 'ERPNumber')
        name = text(node, 'Name')
        guard(id, name) { sync(id, name, text(node, 'Active') != 'false') } if id && name
      end
    end

    private

    def sync(id, name, active)
      carrier = @existing[id]
      return create(id, name, active) unless carrier

      changes = diff(carrier, name: name, active: active)
      carrier.update!(changes) if apply? && changes.any?
      record(changes.any? ? :update : :unchanged, id, name, changes)
    end

    def create(id, name, active)
      PdiCarrier.create!(pdi_carrier_id: id, name: name, active: active) if apply?
      record(:create, id, name, { name: name, active: active })
    end
  end
end
