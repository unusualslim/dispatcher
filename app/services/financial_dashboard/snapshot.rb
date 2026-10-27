class FinancialDashboard
  # Where things stand right now (no period comparison).
  class Snapshot
    OUTSTANDING = (CustomerOrder::ACTIVE_STATUSES - ['Quote']).freeze
    BILLED = ['Released for Billing', 'Billed'].freeze

    def outstanding_orders
      CustomerOrder.where(order_status: OUTSTANDING)
    end

    def outstanding_value
      CustomerOrderProduct.joins(:customer_order).merge(outstanding_orders)
                          .sum(Arel.sql(FinancialDashboard::Sales::AMOUNT)).to_d
    end

    # Billed PDI orders the daily orders.xls hasn't given an invoice date yet (left out of sales).
    def awaiting_invoice_date
      CustomerOrder.where(order_status: BILLED, invoice_date: nil).where.not(external_order_no: nil).count
    end

    def open_price_exceptions
      CustomerOrderProduct.price_mismatches.joins(:customer_order)
                          .where(customer_orders: { order_status: PriceCheckService::OPEN_STATUSES }).count
    end

    def unreviewed_quality_issues
      QualityResult.out_of_range.unreviewed.count
    end

    def inventory_value
      LocationProduct.sum(:inventory_value).to_d if InventoryRevaluation.started?
    end

    def open_purchase_orders
      PurchaseOrder.where(status: %w[approved submitted], voided_at: nil)
    end

    def open_po_value
      PurchaseOrderLineItem.joins(:purchase_order).merge(open_purchase_orders)
                           .sum('purchase_order_line_items.quantity * purchase_order_line_items.unit_cost').to_d
    end

    def credit_holds
      Customer.where("pdi_credit_status = 'Credit Hold' OR pdi_available_credit < 0").count
    end
  end
end
