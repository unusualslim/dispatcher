module PdiOrders
  # Orders entered in the app before PDI became the order source were linked to their PDI order by
  # writing its number (OD-050103-26) in the notes. Once the order sync brings that PDI order in, the app
  # order is merged into it: its dispatch assignments, equipment, quotes and notes move to the PDI order
  # and the app order is deleted, so there's one record, kept current by the sync. PDI's lines win.
  class LinkedOrderMerge
    ORDER_NO = /OD-\d{6}-\d{2}/

    Result = Struct.new(:merged, :errors, keyword_init: true)

    def run
      result = Result.new(merged: [], errors: [])
      linked.each do |app_order, pdi_order|
        merge(app_order, pdi_order)
        result.merged << "#{app_order.id} → #{pdi_order.external_order_no}"
      rescue ActiveRecord::ActiveRecordError => e
        result.errors << "App order #{app_order.id} → #{pdi_order.external_order_no}: #{e.message}"
      end
      result
    end

    private

    # [app order, PDI order] for app-entered orders whose notes name a synced PDI order.
    def linked
      app_orders = CustomerOrder.where(external_order_no: nil).where('notes ~ ?', ORDER_NO.source).to_a
      pdi_orders = CustomerOrder.where(external_order_no: app_orders.map { |o| o.notes[ORDER_NO] })
                                .index_by(&:external_order_no)
      app_orders.filter_map { |order| [order, pdi_orders[order.notes[ORDER_NO]]] if pdi_orders[order.notes[ORDER_NO]] }
    end

    def merge(app_order, pdi_order)
      CustomerOrder.transaction do
        move_dispatches(app_order, pdi_order)
        pdi_order.things << (app_order.things - pdi_order.things)
        Quote.where(customer_order_id: app_order.id).update_all(customer_order_id: pdi_order.id) # rubocop:disable Rails/SkipsModelValidations
        pdi_order.update!(notes: merged_notes(app_order, pdi_order))
        app_order.reload.destroy!
      end
    end

    def move_dispatches(app_order, pdi_order)
      app_order.dispatch_customer_orders.each do |link|
        next link.destroy! if pdi_order.dispatch_customer_orders.exists?(dispatch_id: link.dispatch_id)

        link.update!(customer_order: pdi_order)
      end
    end

    def merged_notes(app_order, pdi_order)
      [pdi_order.notes, "From app order ##{app_order.id}: #{app_order.notes}"].compact_blank.join("\n")
    end
  end
end
