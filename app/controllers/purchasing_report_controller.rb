class PurchasingReportController < ApplicationController
  before_action :require_admin!

  Row = Struct.new(
    :product, :on_hand, :on_order, :committed, :available,
    :inv_min, :inv_max, :qty_to_purchase,
    keyword_init: true
  )

  def index
    products = Product
      .where('is_raw_material = ? OR EXISTS (SELECT 1 FROM product_vendors WHERE product_vendors.product_id = products.id)', true)
      .includes(product_vendors: :vendor)
      .order(:name)

    # Bulk-load on_order and committed quantities to avoid N+1
    product_ids = products.map(&:id)

    on_order_map = PurchaseOrderLineItem
      .joins(:purchase_order)
      .where(product_id: product_ids)
      .where(purchase_orders: { status: %w[draft pending_approval approved submitted] })
      .group(:product_id)
      .sum(:quantity)

    committed_map = ProductionOrderComponent
      .joins(:production_order)
      .where(product_id: product_ids)
      .where(production_orders: { status: %w[pending in_progress] })
      .group(:product_id)
      .sum(:quantity)

    products.each do |p|
      p.instance_variable_set(:@on_order_qty,  on_order_map[p.id]  || 0)
      p.instance_variable_set(:@committed_qty, committed_map[p.id] || 0)
    end

    rows = products.map do |product|
      on_hand   = product.current_stock || 0
      on_order  = product.on_order_qty
      committed = product.committed_qty
      available = product.available_stock
      inv_min   = product.reorder_point.to_f
      inv_max   = product.max_stock

      # Cover demand shortfall OR bring stock up to reorder point, whichever is larger
      qty_to_purchase = [committed.to_f - available.to_f, inv_min.to_f - available.to_f, 0].max.ceil

      Row.new(
        product:          product,
        on_hand:          on_hand,
        on_order:         on_order,
        committed:        committed,
        available:        available,
        inv_min:          inv_min,
        inv_max:          inv_max,
        qty_to_purchase:  qty_to_purchase
      )
    end

    # Filter to only items that need attention
    rows = rows.select { |r| r.qty_to_purchase > 0 || product_status_not_ok?(r.product) }

    # Group by primary vendor; nil → "Unassigned"
    grouped = rows.group_by { |r| r.product.primary_vendor }

    # Sort: named vendors alphabetically first, nil last
    @rows_by_vendor = grouped.sort_by do |vendor, _|
      vendor ? [0, vendor.name.to_s.downcase] : [1, '']
    end.to_h
  end

  private

  def product_status_not_ok?(product)
    product.stock_status != :ok && product.stock_status != :unknown
  end
end
