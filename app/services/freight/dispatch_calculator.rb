module Freight
  # Freight for a whole dispatch. Each order is calculated on its own (customer charges on its own lane), then a
  # carrier that prices per dispatch (a purchase rule set to "Per dispatch, farthest stop", e.g. Five Points
  # Logistics) is priced for the load by LoadPricer. Each part of the load is split back over the orders by
  # gallons as their carrier cost, and the carrier gets one payable for the dispatch.
  class DispatchCalculator
    Result = Struct.new(:summary, :warnings, keyword_init: true)

    attr_reader :dispatch

    def initialize(dispatch)
      @dispatch = dispatch
    end

    def apply!
      order_warnings = orders.flat_map { |order| Calculator.new(order).apply!.warnings }
      pricer = LoadPricer.new(dispatch, orders, gallons)
      summary = dispatch.transaction { reprice!(pricer.call) }
      Result.new(summary: summary, warnings: order_warnings.union(pricer.warnings))
    end

    private

    def reprice!(summary)
      OrderFreightCharge.where(dispatch: dispatch).delete_all
      summary&.dig(:parts)&.each { |part| allocate!(part) }
      sync_payable!(summary)
      dispatch.update!(freight_calculated_at: Time.current)
      summary
    end

    def orders
      @orders ||= dispatch.customer_orders.includes(:location, customer_order_products: { product: :freight_class })
                          .to_a
    end

    # Gallons on each order's lines that have a freight class.
    def gallons
      @gallons ||= orders.index_with { |order| classed_gallons(order) }.select { |_, qty| qty.positive? }
    end

    def classed_gallons(order)
      order.customer_order_products.select { |line| line.product&.freight_class }
           .sum { |line| (line.shipped_quantity || line.quantity).to_d }
    end

    # Splits one part of the load over the orders by gallons, as each order's carrier cost.
    def allocate!(part)
      Allocation.split(part[:amount], gallons).each do |order, share|
        OrderFreightCharge.create!(share_attributes(part).merge(customer_order: order, amount: share,
                                                                quantity: gallons[order],
                                                                rate: (share / gallons[order]).round(4)))
      end
    end

    def share_attributes(part)
      { dispatch: dispatch, side: 'purchase', calculated: true, carrier_id: carrier_vendor_id,
        charge_type: part[:charge_type], freight_rule: part[:rule], basis: part[:rule].basis,
        description: "#{part[:label]} (dispatch ##{dispatch.id}, by gallons)" }
    end

    # The carrier, when it's a vendor in the app (payables need one).
    def carrier_vendor_id
      return @carrier_vendor_id if defined?(@carrier_vendor_id)

      carrier = dispatch.vendor_id.presence || orders.filter_map(&:freight_carrier_vendor_id).first
      @carrier_vendor_id = Vendor.where(id: carrier).pick(:id)
    end

    def sync_payable!(summary)
      vendor_id = summary && carrier_vendor_id
      dispatch.freight_payables.accrued.where.not(vendor_id: vendor_id).destroy_all
      FreightPayable.sync!(dispatch, vendor_id, summary[:total]) if vendor_id
    end
  end
end
