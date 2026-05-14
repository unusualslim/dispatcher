class MrpEngine
  Requirement = Struct.new(
    :product, :total_needed, :available_stock, :shortfall,
    :vendor, :lead_time_days, :order_by_date, :urgent,
    keyword_init: true
  )

  def initialize(horizon_days: 30)
    @horizon_days = horizon_days
  end

  def run
    requirements = Hash.new(0)  # product_id => total quantity needed

    open_production_order_components.each do |comp|
      product_id = comp.product_id.presence || comp.part_number.presence
      next if product_id.nil?
      quantity = comp.quantity || 0
      next if quantity <= 0
      requirements[product_id] += quantity
    end

    requirements.map do |product_id, total_needed|
      product = Product.find_by(id: product_id)
      next unless product

      available     = product.available_stock
      shortfall     = [total_needed - available, 0].max
      vendor        = PurchaseOrder.joins(:vendor).where(product: product)
                        .order(created_at: :desc).first&.vendor
      lead_time     = vendor&.lead_time_days
      order_by_date = lead_time ? Date.today + lead_time.days : nil
      urgent        = shortfall > 0

      Requirement.new(
        product:         product,
        total_needed:    total_needed,
        available_stock: available,
        shortfall:       shortfall,
        vendor:          vendor,
        lead_time_days:  lead_time,
        order_by_date:   order_by_date,
        urgent:          urgent
      )
    end.compact
  end

  private

  def open_production_order_components
    ProductionOrderComponent
      .joins(:production_order)
      .where(production_orders: { status: %w[pending in_progress] })
      .includes(:product)
  end
end
