# Purchasing → Suggested POs: what to buy, from whom and by when, for a person to tick and turn into draft POs
# (which then go through approval as usual). Nothing is ordered automatically.
#
# Two sources:
#   - MRP shortages: the first suggested purchase per bought product and warehouse (Mrp::Plan). Items with a min
#     and max order at least one min/max order (max - min), so a shortage buys a full order, not just the gap.
#   - At or below min: products whose stock + open POs is at or below their min (reorder point) with no MRP
#     shortage; ordered up to max at their main warehouse (most stock, else 0002).
# Draft POs count as supply in MRP, so a line drops off once its draft PO exists. Prices: the vendor's price
# break for the quantity (Vendor prices on the product page), else the last price paid that vendor, else cost.
class SuggestedPurchases # rubocop:disable Metrics/ClassLength -- two sources plus vendor and price lookup
  OPEN_PO = %w[draft pending_approval approved submitted].freeze
  EPOCH = Date.new(1900)
  VENDOR_GUESS = Planning::Assumption.new(:vendor_guess, 'Vendor from last PO',
                                          'No primary vendor on the product; the vendor of its last PO is used.')
  COST_ON_FILE = Planning::Assumption.new(:cost_on_file, 'Price = cost on file',
                                          'No vendor price and nothing bought from this vendor before.')

  Line = Struct.new(:product, :location, :vendor, :quantity, :unit_cost, :vendor_part_number, :act_by,
                    :need_date, :reason, :assumptions, keyword_init: true) do
    def late?(today = Date.current) = act_by < today
  end

  def initialize(today: Date.current, horizon_days: 60)
    @today = today
    @horizon_days = horizon_days
  end

  def lines
    @lines ||= begin
      shortage = mrp_lines
      covered = shortage.to_set { |line| line.product.id }
      (shortage + below_min_lines(covered)).sort_by { |l| [l.vendor&.name.to_s, l.act_by, l.product.id] }
    end
  end

  # Ticked lines → one draft PO per vendor and warehouse.
  # picks: [{ product_id:, location_id:, vendor_id:, quantity:, unit_cost:, vendor_part_number:, need_date: }]
  def self.create_pos!(picks, user:)
    products = Product.where(id: picks.pluck(:product_id)).index_by(&:id)
    usable(picks, products).group_by { |p| [p[:vendor_id], p[:location_id].presence] }
                           .map { |(vendor, location), rows| draft_po!(vendor, location, rows, products, user) }
  end

  def self.usable(picks, products)
    picks.select { |p| products[p[:product_id]] && p[:vendor_id].present? && p[:quantity].to_d.positive? }
  end

  def self.draft_po!(vendor_id, location_id, rows, products, user)
    PurchaseOrder.transaction do
      po = PurchaseOrder.create!(vendor_id: vendor_id, location_id: location_id, status: 'draft',
                                 po_type: 'inventory', trigger_type: 'mrp_shortage',
                                 trigger_reason: "Suggested POs, created by #{user.full_name.presence || user.email}",
                                 expected_delivery_date: rows.filter_map { |r| r[:need_date].presence }.min)
      rows.each { |row| add_line!(po, products[row[:product_id]], row) }
      po
    end
  end

  def self.add_line!(order, product, row)
    order.line_items.create!(product: product, product_name: product.name, quantity: row[:quantity].to_d,
                             unit_cost: row[:unit_cost].presence&.to_d || product.cost_per_unit,
                             vendor_part_number: row[:vendor_part_number].presence)
  end

  private

  def plan
    @plan ||= Mrp::Plan.new(today: @today, horizon_days: @horizon_days).run
  end

  def mrp_lines
    plan.plans.values.reject(&:manufactured?).filter_map { |product_plan| shortage_line(product_plan) }
  end

  def shortage_line(product_plan)
    first = product_plan.suggestions.min_by(&:act_by)
    return unless first

    product = product_plan.product
    line(product, product_plan.location, [first.qty, min_max_order(product)].compact.max,
         act_by: first.act_by, need_date: first.need_date, reason: "Short #{first.need_date.strftime('%b %-d')} (MRP)",
         assumptions: product_plan.assumptions)
  end

  def below_min_lines(covered)
    bought = Product.where(id: plan.plans.keys.map(&:first).uniq).where.not(reorder_point: nil)
                    .where.not(id: covered.to_a + ProductComponent.select(:product_id))
                    .includes(product_vendors: :vendor)
    bought.filter_map { |product| below_min_line(product) }
  end

  def below_min_line(product)
    position = position(product)
    qty = (product.max_stock.presence || product.reorder_point).to_d - position
    return unless position <= product.reorder_point && qty.positive?

    lead = Planning::LeadTime.purchase(product)
    line(product, home(product), qty, act_by: @today, need_date: @today + lead.days,
                                      reason: below_min_reason(product, position),
                                      assumptions: [lead.assumption(made: false)].compact)
  end

  def position(product) = on_hand.fetch(product.id, 0).to_d + on_order.fetch(product.id, 0).to_d

  def below_min_reason(product, position)
    "At or below min (#{fmt(position)} on hand + on order, min #{fmt(product.reorder_point)})"
  end

  def line(product, location, quantity, assumptions:, **dates_and_reason)
    vendor, vendor_note = pick_vendor(product)
    price = vendor_price(product, vendor, quantity)
    cost, cost_note = unit_cost(product, vendor, price)
    Line.new(product: product, location: location, vendor: vendor, quantity: quantity.ceil, unit_cost: cost,
             vendor_part_number: price&.vendor_part_number, **dates_and_reason,
             assumptions: [*assumptions, vendor_note, cost_note].compact)
  end

  def pick_vendor(product)
    return [product.primary_vendor, nil] if product.primary_vendor

    vendor = last_vendor(product)
    [vendor, (VENDOR_GUESS if vendor)]
  end

  def unit_cost(product, vendor, price)
    return [price.unit_cost, nil] if price

    last = last_cost(product, vendor)
    last ? [last, nil] : [product.cost_per_unit, COST_ON_FILE]
  end

  def min_max_order(product)
    return unless product.max_stock && product.reorder_point

    (product.max_stock - product.reorder_point).abs.nonzero?
  end

  # The vendor's price for the quantity: the largest price break the quantity reaches, newest first.
  def vendor_price(product, vendor, quantity)
    link = vendor && product.product_vendors.find { |pv| pv.vendor_id == vendor.id }
    return unless link

    prices = VendorItemPrice.where(product_vendor_id: link.id)
                            .where('effective_on IS NULL OR effective_on <= ?', @today)
    prices.select { |p| p.min_quantity.to_d <= quantity }.max_by { |p| [p.min_quantity.to_d, p.effective_on || EPOCH] }
  end

  def last_line(product, vendor = nil)
    scope = PurchaseOrderLineItem.joins(:purchase_order)
                                 .where(product_id: product.id, purchase_orders: { voided_at: nil })
    scope = scope.where(purchase_orders: { vendor_id: vendor.id }) if vendor
    scope.order('purchase_orders.created_at DESC').first
  end

  def last_vendor(product) = last_line(product)&.purchase_order&.vendor
  def last_cost(product, vendor) = vendor && last_line(product, vendor)&.unit_cost

  def on_hand
    @on_hand ||= LocationProduct.group(:product_id).sum(:quantity)
  end

  def on_order
    @on_order ||= PurchaseOrderLineItem.joins(:purchase_order)
                                       .where(purchase_orders: { status: OPEN_PO, po_type: 'inventory' })
                                       .where(purchase_orders: { voided_at: nil })
                                       .group(:product_id).sum(:quantity)
  end

  def home(product)
    id = LocationProduct.where(product_id: product.id).where('quantity > 0').order(quantity: :desc).pick(:location_id)
    Location.find_by(id: id) || Location.find_by(pdi_site_code: Mrp::Plan::MAIN_SITE)
  end

  def fmt(qty) = qty.to_d.round(1).to_s('F').delete_suffix('.0')
end
