class PdiWebService
  # Filter XML for GetWarehouseOrders / GetFuelOrders, validated against PDI's PDIGet*OrdersInput schema
  # (docs/pdi_api). It only matches with xmlns="", and elements must follow the schema's order.
  # RecordsToInclude (PDI's docs): 0 = new only, 1 = new and changed, 2 = changed only (those three only
  # return orders not yet sent to this web partner, and mark them sent: the flags can't be reset, and PDI's
  # test tool shares the partner, so testing with them eats the feed), 3 = all records matching the filter.
  # PDI writes "Order fetched via OD web service" to each returned order's audit log, so frequent runs use
  # new-and-changed and only the nightly run asks for everything (PdiOrders::Feed).
  module OrderFilter
    # rubocop:disable Metrics/ParameterLists -- one keyword per optional schema element
    def self.xml(name, statuses:, from: nil, to: nil, order_no: nil, records: RECORDS_ALL)
      # rubocop:enable Metrics/ParameterLists
      status_xml = Array(statuses).map { |s| "<Status>#{Integer(s)}</Status>" }.join
      input = "<StatusToInclude>#{status_xml}</StatusToInclude><RecordsToInclude>#{Integer(records)}</RecordsToInclude>"
      if from && to
        input += "<SchedDelivDateTimeFrom>#{from.to_date.iso8601}T00:00:00</SchedDelivDateTimeFrom>" \
                 "<SchedDelivDateTimeTo>#{to.to_date.iso8601}T23:59:59</SchedDelivDateTimeTo>"
      end
      input += "<OrderNo>#{ERB::Util.html_escape(order_no)}</OrderNo>" if order_no
      "<#{name}Filter><#{name}Input xmlns=\"\">#{input}</#{name}Input></#{name}Filter>"
    end
  end
end
