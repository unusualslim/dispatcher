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

    open_orders.each do |order_product|
      product  = order_product.product
      next if product.nil?
      quantity = order_product.quantity || 0
      next if quantity <= 0

      bom_lines = ProductComponent.where(product_id: product.id)
      bom_lines.each do |line|
        requirements[line.component_product_id] += line.quantity_per_unit * quantity
      end
    end

    requirements.map do |product_id, total_needed|
      product = Product.find_by(id: product_id)
      next unless product&.is_raw_material?

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

  def open_orders
    CustomerOrderProduct
      .joins(:customer_order)
      .where(customer_orders: { order_status: open_statuses })
      .where(customer_orders: { required_delivery_date: ...(Date.today + @horizon_days) })
      .includes(:product, :customer_order)
  end

  def open_statuses
    # Matches actual CustomerOrder enum values: "New" and "On Hold"
    ['New', 'On Hold']
  end
end
