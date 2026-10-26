module PdiOrders
  # Pulls fuel and warehouse orders from PDI into one document that PdiOrderApiImportService reads
  # (and the SyncLog keeps, so a run can be imported again):
  #   <PDIOrderFeed><Batch type="warehouse" status="1"><PDIWarehouseOrders>…</PDIWarehouseOrders></Batch>…
  # PDI hands each order to this web partner only once until it changes, so one failed call is noted
  # and the rest still run: whatever arrived has to be saved.
  class Feed
    # Delivery-date window (days) for finished statuses.
    LOOKBACK = 60
    LOOKAHEAD = 365

    attr_reader :errors

    def initialize(client = PdiWebService.new, today: Date.current)
      @client = client
      @today = today
      @errors = []
    end

    def fetch
      doc = Nokogiri::XML::Document.new
      doc.root = doc.create_element('PDIOrderFeed', fetched_at: Time.current.iso8601)
      batches.each do |type, statuses|
        add(doc.root, type, statuses)
      rescue *PdiWebService::FAILURES => e
        @errors << "#{type} orders (status #{statuses.join(', ')}): #{e.message}"
      end
      doc.to_xml
    end

    private

    # Each warehouse status on its own; fuel in two calls (open statuses undated, finished ones dated).
    def batches
      Statuses::WAREHOUSE.map { |status| ['warehouse', [status]] } +
        (Statuses::FUEL - Statuses::DATED).then { |open| [['fuel', open], ['fuel', Statuses::FUEL & Statuses::DATED]] }
    end

    def add(root, type, statuses)
      result = @client.public_send(:"#{type}_orders", statuses: statuses, **window(statuses))
      batch = root.add_child(root.document.create_element('Batch', type: type, status: statuses.join(' ')))
      batch.add_child(result.dup(1))
    end

    def window(statuses)
      return {} unless statuses.intersect?(Statuses::DATED)

      { from: @today - LOOKBACK, to: @today + LOOKAHEAD }
    end
  end
end
