module Freight
  # One payable per carrier on an order, accruing its purchase freight. A carrier whose charges are gone loses its
  # payable unless the invoice was already entered.
  module OrderPayables
    module_function

    def sync!(order)
      totals = carrier_totals(order)
      totals.each { |vendor_id, amount| FreightPayable.sync!(order, vendor_id, amount) }
      gone = order.freight_payables.where.not(vendor_id: totals.keys)
      gone.accrued.destroy_all
      gone.invoiced.find_each { |payable| payable.update!(accrued_amount: 0) }
    end

    # { carrier vendor id => purchase freight }
    def carrier_totals(order)
      order.order_freight_charges.purchase.where(dispatch_id: nil).where.not(carrier_id: nil)
           .group(:carrier_id).sum(:amount)
    end
  end
end
