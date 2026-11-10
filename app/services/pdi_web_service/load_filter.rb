class PdiWebService
  # Filter XML for GetFuelLoads (docs/pdi_api/PDIGetFuelLoadsInput.xsd), sent like OrderFilter: with
  # xmlns="" and elements in the schema's order. Statuses are order status codes; dates filter on the
  # actual delivery date (the schema has no business-date filter). RecordsToInclude as on the order calls:
  # only 3 (all matching) leaves PDI's sent flags alone.
  module LoadFilter
    def self.xml(statuses:, from:, to:, carrier_id: nil, records: RECORDS_ALL)
      status_xml = Array(statuses).map { |s| "<Status>#{Integer(s)}</Status>" }.join
      input = "<StatusToInclude>#{status_xml}</StatusToInclude><RecordsToInclude>#{Integer(records)}</RecordsToInclude>"
      input += "<CarrierID>#{ERB::Util.html_escape(carrier_id)}</CarrierID>" if carrier_id
      input += "<ActualDelivDateTimeFrom>#{from.to_date.iso8601}T00:00:00</ActualDelivDateTimeFrom>" \
               "<ActualDelivDateTimeTo>#{to.to_date.iso8601}T23:59:59</ActualDelivDateTimeTo>"
      "<PDIGetFuelLoadsFilter><PDIGetFuelLoadsInput xmlns=\"\">#{input}</PDIGetFuelLoadsInput></PDIGetFuelLoadsFilter>"
    end
  end
end
