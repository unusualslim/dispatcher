class PdiWebService
  # Filter XML for GetWarehouseOrders / GetFuelOrders, validated against PDI's PDIGet*OrdersInput schema
  # (docs/pdi_api). It only matches with xmlns="", and elements must follow the schema's order.
  # RecordsToInclude doesn't change what comes back: with 0 or 1, PDI hands each order to this partner
  # once and then leaves it out until it changes.
  module OrderFilter
    def self.xml(name, statuses:, from: nil, to: nil, order_no: nil)
      status_xml = Array(statuses).map { |s| "<Status>#{Integer(s)}</Status>" }.join
      input = "<StatusToInclude>#{status_xml}</StatusToInclude><RecordsToInclude>1</RecordsToInclude>"
      if from && to
        input += "<SchedDelivDateTimeFrom>#{from.to_date.iso8601}T00:00:00</SchedDelivDateTimeFrom>" \
                 "<SchedDelivDateTimeTo>#{to.to_date.iso8601}T23:59:59</SchedDelivDateTimeTo>"
      end
      input += "<OrderNo>#{ERB::Util.html_escape(order_no)}</OrderNo>" if order_no
      "<#{name}Filter><#{name}Input xmlns=\"\">#{input}</#{name}Input></#{name}Filter>"
    end
  end
end
