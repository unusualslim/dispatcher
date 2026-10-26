# Syncs PDI master data (the web service's GetMasterData file) into the app:
#   customers  → customers.pdi_customer_id (first run links existing customers by name)
#   ship-tos   → customer_locations.pdi_location_id (PDI ship-to IDs are per customer; app locations
#                are shared places, so one location can serve many customers' ship-tos)
#   terminals  → locations.pdi_terminal_id, linked to existing origin locations by name (never created)
#   products   → fuel and warehouse products by PDI item ID (= products.id)
# Each section lives in app/services/pdi_master_data/. preview runs the same matching without saving.
class PdiMasterDataImportService
  SECTIONS = {
    customers: 'Customers', ship_tos: 'Ship-to locations', terminals: 'Terminals', products: 'Products'
  }.freeze

  # action: :create, :update, :link (existing record gets its PDI ID), :unchanged, :skip, :error
  Change = Struct.new(:section, :action, :key, :label, :changes, :note, keyword_init: true)

  Result = Struct.new(:changes) do
    def count(section, action)
      changes.count { |c| c.section == section && c.action == action }
    end

    def for(section, *actions)
      changes.select { |c| c.section == section && actions.include?(c.action) }
    end

    def total(action)
      changes.count { |c| c.action == action }
    end

    def errors
      changes.select { |c| c.action == :error }.map { |c| "#{SECTIONS[c.section]} #{c.key}: #{c.note}" }
    end
  end

  def self.call(xml)
    new(xml).run
  end

  def initialize(xml)
    @doc = Nokogiri::XML(xml)
    @doc.remove_namespaces!
  end

  def preview
    sync(apply: false)
  end

  def run
    sync(apply: true)
  end

  private

  def sync(apply:)
    context = PdiMasterData::Sync::Context.new(apply, [], {})
    [PdiMasterData::CustomerSync, PdiMasterData::ShipToSync, PdiMasterData::TerminalSync,
     PdiMasterData::ProductSync].each { |section| section.new(@doc, context).call }
    Result.new(context.changes)
  end
end
