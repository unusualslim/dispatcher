module PdiOrders
  # Pulls fuel and warehouse orders from PDI into one document that PdiOrderApiImportService reads
  # (and the SyncLog keeps, so a run can be imported again):
  #   <PDIOrderFeed mode="changes"><Batch type="warehouse" status="1"><PDIWarehouseOrders>…</PDIWarehouseOrders>…
  # PDI audits every order it hands out, so there are two modes:
  # - :changes (every 15 min): only orders new or changed since PDI last sent them (RecordsToInclude 1;
  #   PDI then marks them sent). Finished statuses for delivery dates in the last 60 days.
  # - :full (nightly): every matching order (RecordsToInclude 3), catching anything a changes run missed.
  #   Finished statuses only for the last week, so a billed order is fetched a handful of times, not for 60 days.
  # A failed call is noted and the rest still run.
  class Feed
    MODES = {
      changes: { records: PdiWebService::RECORDS_NEW_AND_CHANGED, lookback: 60 },
      full: { records: PdiWebService::RECORDS_ALL, lookback: 7 }
    }.freeze
    # Delivery-date window (days ahead) for finished statuses.
    LOOKAHEAD = 365

    attr_reader :errors, :mode

    def initialize(client = PdiWebService.new, today: Date.current, mode: :full)
      @client = client
      @today = today
      @mode = mode
      @settings = MODES.fetch(mode)
      @errors = []
    end

    def fetch
      doc = Nokogiri::XML::Document.new
      doc.root = doc.create_element('PDIOrderFeed', fetched_at: Time.current.iso8601, mode: @mode.to_s)
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
      result = @client.public_send(:"#{type}_orders", statuses: statuses, records: @settings[:records],
                                                      **window(statuses))
      batch = root.add_child(root.document.create_element('Batch', type: type, status: statuses.join(' ')))
      batch.add_child(result.dup(1))
    end

    def window(statuses)
      return {} unless statuses.intersect?(Statuses::DATED)

      { from: @today - @settings[:lookback], to: @today + LOOKAHEAD }
    end
  end
end
