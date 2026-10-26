module PdiMasterData
  # Base for the section syncs that PdiMasterDataImportService runs in order.
  class Sync
    # customers: PDI customer ID → Customer, filled by CustomerSync (nil while a preview "creates" one)
    Context = Struct.new(:apply, :changes, :customers)

    def initialize(doc, context)
      @doc = doc
      @context = context
    end

    private

    def apply?
      @context.apply
    end

    def customers
      @context.customers
    end

    def customer_nodes
      @doc.xpath('//Destinations/Customers/Customer').select { |node| text(node, 'ID') && text(node, 'Description') }
    end

    def record(action, key, label, changes = {}, note = nil)
      @context.changes << PdiMasterDataImportService::Change.new(
        section: self.class::SECTION, action: action, key: key, label: label, changes: changes, note: note
      )
    end

    # One bad record is reported and the rest carry on.
    def guard(key, label)
      yield
    rescue StandardError => e
      record(:error, key, label, {}, e.message)
    end

    def diff(record, attrs)
      attrs.reject do |field, value|
        current = record[field]
        current.is_a?(BigDecimal) || value.is_a?(BigDecimal) ? current.to_d == value.to_d : current.to_s == value.to_s
      end
    end

    def text(node, path)
      node.at_xpath(path)&.text&.strip.presence
    end

    # "12 - Southern Performance Chemical" (FTP order import names) == "southern performance chemical"
    def normalize(name)
      name.to_s.sub(/\A\d+\s*-\s*/, '').downcase.gsub(/[^a-z0-9]+/, ' ').squish
    end

    # Same name, street address and 5-digit zip = same physical place.
    def place_key(location)
      [normalize(location.company_name), normalize(location.address), location.zip.to_s.strip[0, 5]]
    end
  end
end
