class PdiWebService
  # Filter XML for GetWarehouseOrders / GetFuelOrders, validated against PDI's PDIGet*OrdersInput schema
  # (docs/pdi_api). It only matches with xmlns="", and elements must follow the schema's order.
  # RecordsToInclude (PDI's docs): 0 = new only, 1 = new and changed, 2 = changed only (those three only
  # return orders not yet sent to this web partner, and mark them sent: the flags can't be reset),
  # 3 = all records matching the filter. Always 3.
  RECORDS_ALL = 3
  module OrderFilter
    def self.xml(name, statuses:, from: nil, to: nil, order_no: nil)
      status_xml = Array(statuses).map { |s| "<Status>#{Integer(s)}</Status>" }.join
      input = "<StatusToInclude>#{status_xml}</StatusToInclude><RecordsToInclude>#{RECORDS_ALL}</RecordsToInclude>"
      if from && to
        input += "<SchedDelivDateTimeFrom>#{from.to_date.iso8601}T00:00:00</SchedDelivDateTimeFrom>" \
                 "<SchedDelivDateTimeTo>#{to.to_date.iso8601}T23:59:59</SchedDelivDateTimeTo>"
      end
      input += "<OrderNo>#{ERB::Util.html_escape(order_no)}</OrderNo>" if order_no
      "<#{name}Filter><#{name}Input xmlns=\"\">#{input}</#{name}Input></#{name}Filter>"
    end
  end
end
