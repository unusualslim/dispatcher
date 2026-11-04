# Posts the stock movements of records already in the app for a past period, oldest first: PO receipts,
# completed production orders and shipped PDI orders. Used after back-dated opening balances (Inventory
# Valuation → Set opening balances as of a date), so the app's numbers can be checked against PDI's for a
# closed month. Each record is posted only if it isn't already: running it twice changes nothing.
#
# Manual inventory adjustments aren't replayed (they're entered by hand, not kept as documents).
class InventoryReplay
  Event = Struct.new(:date, :rank, :kind, :record)
  KINDS = { receipt: 0, production: 1, sale: 2 }.freeze

  attr_reader :from, :to, :counts, :errors

  def initialize(from:, to: Date.current)
    @from = from
    @to = to
    @counts = KINDS.keys.index_with(0)
    @errors = []
  end

  def run!
    start = InventoryRevaluation.start_date
    raise ArgumentError, 'Set opening balances first' unless start
    raise ArgumentError, "Can't replay before the opening balances (#{start})" if from < start
    raise ArgumentError, 'The period ends before it starts' if to < from

    events.sort_by { |event| [event.date, event.rank, event.record.id] }.each { |event| post(event) }
    self
  end

  def summary
    text = "Replayed #{from}…#{to}: #{counts[:receipt]} PO receipt(s), #{counts[:production]} production order(s), " \
           "#{counts[:sale]} shipped order(s)"
    errors.any? ? "#{text}; #{errors.size} failed (#{errors.first(5).join('; ')})" : "#{text}."
  end

  private

  def events
    receipts + productions + sales
  end

  def receipts
    PurchaseOrder.inventory_type.where(status: 'received', voided_at: nil, received_at: period_times)
                 .where.not(location_id: nil)
                 .map { |po| Event.new(po.received_at.to_date, KINDS[:receipt], :receipt, po) }
  end

  def productions
    ProductionOrder.where(status: 'completed', date_completed: from..to)
                   .map { |order| Event.new(order.date_completed, KINDS[:production], :production, order) }
  end

  def period_times
    from.beginning_of_day..to.end_of_day
  end

  # Candidates by any of the dates InventorySales ships on, then kept by the date it actually uses.
  def sales
    sale_candidates.filter_map do |order|
      date = InventorySales.ship_date(order)
      Event.new(date, KINDS[:sale], :sale, order) if (from..to).cover?(date)
    end
  end

  # order_date is a timestamp: a day either side, the exact date is checked after.
  def sale_candidates
    CustomerOrder.where.not(external_order_no: [nil, ''])
                 .where(order_status: InventorySales::SHIPPED_STATUSES)
                 .where('invoice_date BETWEEN :f AND :t OR required_delivery_date BETWEEN :f AND :t OR ' \
                        'CAST(order_date AS date) BETWEEN :f1 AND :t1', f: from, t: to, f1: from - 1, t1: to + 1)
  end

  def post(event)
    posted = ActiveRecord::Base.transaction(requires_new: true) { send(:"posted_#{event.kind}?", event.record) }
    counts[event.kind] += 1 if posted
  rescue StandardError => e
    errors << "#{label(event)}: #{e.message}"
  end

  # PDI-imported POs received before tracking were only stamped posted; post them now unless their
  # receipts are already in.
  def posted_receipt?(order)
    return false if InventoryTransaction.where(transactable: order, movement_type: 'receipt').in_effect.exists?

    order.update_columns(posted_at: nil) # rubocop:disable Rails/SkipsModelValidations -- PDI history can fail validations
    order.reload.post_to_inventory!(nil)
  end

  def posted_production?(order)
    return false if ProductionOrderInventory.posted?(order)

    ProductionOrderInventory.post!(order)
    true
  end

  def posted_sale?(order)
    before = InventoryTransaction.where(transactable: order).count
    InventorySales.sync!(order)
    InventoryTransaction.where(transactable: order).count != before
  end

  def label(event)
    record = event.record
    name = case event.kind
           when :receipt then "PO #{record.pdi_reference || record.id}"
           when :production then record.number
           else "Order #{record.external_order_no}"
           end
    "#{name} (#{event.date})"
  end
end
