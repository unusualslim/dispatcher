class InventoryIntelligenceService
  Report = Struct.new(
    :generated_at,
    :stock_summary,
    :critical_items,
    :low_items,
    :demand_outlook,
    :supply_pipeline,
    :consumption_trends,
    :recommendations,
    keyword_init: true
  )

  StockSummary = Struct.new(
    :total_products, :critical_count, :low_count, :ok_count,
    :total_stock_value, :total_on_order_value,
    keyword_init: true
  )

  ItemSnapshot = Struct.new(
    :product, :current_stock, :on_order, :committed, :available,
    :reorder_point, :safety_stock, :stock_status,
    :days_of_supply, :primary_vendor, :lead_time_days,
    keyword_init: true
  )

  DemandLine = Struct.new(
    :product, :total_qty_needed, :order_count, :earliest_delivery_date,
    :available_stock, :shortfall,
    keyword_init: true
  )

  SupplyLine = Struct.new(
    :purchase_order, :vendor, :product, :quantity,
    :status, :expected_delivery_date, :days_until_arrival,
    keyword_init: true
  )

  ConsumptionTrend = Struct.new(
    :product, :avg_daily_usage_30d, :avg_daily_usage_7d,
    :trend_direction, :current_stock, :estimated_days_remaining,
    keyword_init: true
  )

  Recommendation = Struct.new(
    :priority, :category, :message, :product,
    keyword_init: true
  )

  def initialize(report_type: :daily)
    @report_type = report_type
  end

  def run
    products = Product.where.not(is_raw_material: nil)
                      .includes(:product_vendors, vendors: [])
                      .to_a

    preload_bulk_data(products)

    Report.new(
      generated_at:       Time.current,
      stock_summary:      build_stock_summary(products),
      critical_items:     build_item_snapshots(products, :critical),
      low_items:          build_item_snapshots(products, :low),
      demand_outlook:     build_demand_outlook,
      supply_pipeline:    build_supply_pipeline,
      consumption_trends: build_consumption_trends(products),
      recommendations:    build_recommendations(products)
    )
  end

  private

  # Bulk-load on_order and committed quantities to avoid N+1
  def preload_bulk_data(products)
    product_ids = products.map(&:id)

    on_order = PurchaseOrderLineItem
      .joins(:purchase_order)
      .where(product_id: product_ids)
      .where(purchase_orders: { status: %w[draft pending_approval approved submitted] })
      .group(:product_id).sum(:quantity)

    committed = ProductionOrderComponent
      .joins(:production_order)
      .where(product_id: product_ids)
      .where(production_orders: { status: %w[pending in_progress] })
      .group(:product_id).sum(:quantity)

    products.each do |p|
      p.instance_variable_set(:@on_order_qty, on_order[p.id] || 0)
      p.instance_variable_set(:@committed_qty, committed[p.id] || 0)
    end
  end

  def build_stock_summary(products)
    statuses = products.map(&:stock_status)
    critical = statuses.count(:critical)
    low      = statuses.count(:low)
    ok       = statuses.count(:ok)

    total_value    = products.sum { |p| (p.current_stock || 0) * (p.standard_cost || p.cost_per_unit || 0) }
    on_order_value = products.sum { |p| p.on_order_qty * (p.standard_cost || p.cost_per_unit || 0) }

    StockSummary.new(
      total_products:      products.size,
      critical_count:      critical,
      low_count:           low,
      ok_count:            ok,
      total_stock_value:   total_value,
      total_on_order_value: on_order_value
    )
  end

  def build_item_snapshots(products, status_filter)
    products
      .select { |p| p.stock_status == status_filter }
      .map { |p| item_snapshot(p) }
      .sort_by { |s| s.days_of_supply || Float::INFINITY }
  end

  def item_snapshot(product)
    vendor = product.primary_vendor
    ItemSnapshot.new(
      product:        product,
      current_stock:  product.current_stock || 0,
      on_order:       product.on_order_qty,
      committed:      product.committed_qty,
      available:      product.available_stock,
      reorder_point:  product.reorder_point,
      safety_stock:   product.safety_stock,
      stock_status:   product.stock_status,
      days_of_supply: days_of_supply(product),
      primary_vendor: vendor,
      lead_time_days: vendor&.lead_time_days
    )
  end

  # Aggregate active customer order demand by product
  def build_demand_outlook
    rows = CustomerOrderProduct
      .joins(:customer_order)
      .where(customer_orders: { order_status: CustomerOrder::ACTIVE_STATUSES })
      .where.not(product_id: nil)
      .group(:product_id)
      .select(
        'product_id',
        'SUM(customer_order_products.quantity) AS total_qty',
        'COUNT(DISTINCT customer_order_id) AS order_count',
        'MIN(customer_orders.required_delivery_date) AS earliest_date'
      )

    product_ids = rows.map(&:product_id)
    products_by_id = Product.where(id: product_ids).index_by(&:id)

    rows.filter_map do |row|
      product = products_by_id[row.product_id]
      next unless product

      total   = row.total_qty.to_d
      avail   = product.available_stock
      DemandLine.new(
        product:                product,
        total_qty_needed:       total,
        order_count:            row.order_count,
        earliest_delivery_date: row.earliest_date,
        available_stock:        avail,
        shortfall:              [total - avail, 0].max
      )
    end.sort_by { |d| d.shortfall > 0 ? 0 : 1 }
  end

  # Active POs with line items — what's coming in
  def build_supply_pipeline
    PurchaseOrderLineItem
      .joins(purchase_order: :vendor)
      .where(purchase_orders: { status: %w[approved submitted] })
      .includes(purchase_order: :vendor, product: [])
      .map do |li|
        po = li.purchase_order
        days = if po.expected_delivery_date
                 (po.expected_delivery_date - Date.today).to_i
               end
        SupplyLine.new(
          purchase_order:         po,
          vendor:                 po.vendor,
          product:                li.product,
          quantity:               li.quantity,
          status:                 po.status,
          expected_delivery_date: po.expected_delivery_date,
          days_until_arrival:     days
        )
      end
      .sort_by { |s| s.days_until_arrival || Float::INFINITY }
  end

  # Consumption velocity from inventory transactions over recent windows
  def build_consumption_trends(products)
    now = Time.current
    outbound_30d = InventoryTransaction.outbound
      .where('created_at >= ?', now - 30.days)
      .group(:product_id).sum(:quantity)

    outbound_7d = InventoryTransaction.outbound
      .where('created_at >= ?', now - 7.days)
      .group(:product_id).sum(:quantity)

    products.filter_map do |p|
      usage_30 = outbound_30d[p.id]
      usage_7  = outbound_7d[p.id]
      next unless usage_30 && usage_30 > 0

      avg_30 = usage_30 / 30.0
      avg_7  = usage_7 ? usage_7 / 7.0 : 0

      trend = if avg_7 > avg_30 * 1.2
                :increasing
              elsif avg_7 < avg_30 * 0.8
                :decreasing
              else
                :stable
              end

      stock = p.current_stock || 0
      est_days = avg_30 > 0 ? (stock / avg_30).round(1) : nil

      ConsumptionTrend.new(
        product:                p,
        avg_daily_usage_30d:    avg_30.round(2),
        avg_daily_usage_7d:     avg_7.round(2),
        trend_direction:        trend,
        current_stock:          stock,
        estimated_days_remaining: est_days
      )
    end.sort_by { |t| t.estimated_days_remaining || Float::INFINITY }
  end

  # Generate actionable recommendations
  def build_recommendations(products)
    recs = []

    products.each do |p|
      # Critical shortage — needs immediate action
      if p.stock_status == :critical
        dos = days_of_supply(p)
        lead = p.primary_vendor&.lead_time_days
        msg = "#{p.name} is critically low (#{fmt(p.current_stock)} on hand, #{fmt(p.available_stock)} available)."
        if lead && dos && dos < lead
          msg += " Stock will run out before next delivery (#{dos.round(1)} days supply vs #{lead} day lead time)."
        end
        recs << Recommendation.new(priority: :critical, category: :shortage, message: msg, product: p)
      end

      # Below safety stock
      if p.safety_stock && p.safety_stock > 0 && (p.current_stock || 0) < p.safety_stock
        recs << Recommendation.new(
          priority: :high, category: :safety_stock,
          message: "#{p.name} is below safety stock (#{fmt(p.current_stock)} vs #{fmt(p.safety_stock)} safety).",
          product: p
        )
      end

      # Overstock warning
      if p.max_stock && p.max_stock > 0 && (p.current_stock || 0) > p.max_stock
        recs << Recommendation.new(
          priority: :info, category: :overstock,
          message: "#{p.name} exceeds max stock (#{fmt(p.current_stock)} vs #{fmt(p.max_stock)} max).",
          product: p
        )
      end
    end

    # Demand with no supply coverage
    build_demand_outlook.each do |d|
      next unless d.shortfall > 0
      recs << Recommendation.new(
        priority: :high, category: :demand_gap,
        message: "#{d.product.name}: #{fmt(d.shortfall)} short for #{d.order_count} active order(s). Earliest delivery needed #{d.earliest_delivery_date&.strftime('%b %d')}.",
        product: d.product
      )
    end

    # Overdue POs
    PurchaseOrder.where(status: %w[approved submitted])
                 .where('expected_delivery_date < ?', Date.today)
                 .includes(:vendor)
                 .each do |po|
      days_late = (Date.today - po.expected_delivery_date).to_i
      recs << Recommendation.new(
        priority: :high, category: :overdue_po,
        message: "PO ##{po.id} from #{po.vendor&.name} is #{days_late} day(s) overdue (expected #{po.expected_delivery_date.strftime('%b %d')}).",
        product: nil
      )
    end

    recs.sort_by { |r| { critical: 0, high: 1, info: 2 }[r.priority] || 3 }
  end

  def days_of_supply(product)
    usage_30d = InventoryTransaction.outbound
      .where(product_id: product.id)
      .where('created_at >= ?', 30.days.ago)
      .sum(:quantity)
    return nil if usage_30d <= 0

    avg_daily = usage_30d / 30.0
    ((product.current_stock || 0) / avg_daily).round(1)
  end

  def fmt(val)
    return '0' if val.nil?
    val == val.to_i ? val.to_i.to_s : sprintf('%.1f', val)
  end
end
