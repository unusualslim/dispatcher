module PdiOrders
  # PDI's numeric order statuses (OrderStatusType in docs/pdi_api/PDIOrderElementTypes.xsd), named as
  # CustomerOrder#order_status stores them.
  module Statuses
    NAMES = {
      0 => 'Quote', 1 => 'Open Order', 2 => 'Picking in Progress', 3 => 'Shipped', 4 => 'Dispatched',
      5 => 'Released for Billing', 6 => 'Billed', 7 => 'Cancelled as Quote', 8 => 'Cancelled as Order',
      9 => 'Expired Quote', 10 => 'Released for Dispatch', 11 => 'Credited', 12 => 'Released for Picking',
      13 => 'Accepted by Site', 14 => 'Rejected by Site', 15 => 'Delivered', 16 => 'Pending', 17 => 'Staged',
      18 => 'Loaded'
    }.freeze

    # Warehouse orders don't say their status, so they're fetched one status at a time; picking is
    # warehouse-only and dispatch/site statuses are fuel-only. Fuel orders carry <OrderStatus>.
    WAREHOUSE = [0, 1, 2, 3, 5, 6, 7, 8, 9, 11, 12, 16].freeze
    FUEL = (NAMES.keys - [2, 12]).freeze

    # Finished statuses are fetched for recent delivery dates only: undated, PDI hands out years-old orders.
    DATED = [6, 7, 8, 9, 11].freeze

    def self.name(code)
      NAMES.fetch(code) { raise ArgumentError, "unknown PDI order status #{code.inspect}" }
    end

    # CustomerOrder enum key ("open_order") for a PDI status code.
    def self.enum_key(code)
      CustomerOrder.order_statuses.key(name(code))
    end
  end
end
