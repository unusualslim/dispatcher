class MrpEngine
  Requirement = Struct.new(
    :product, :description, :total_needed, :available_stock, :shortfall,
    :vendor, :lead_time_days, :order_by_date, :urgent,
    keyword_init: true
  )

  def initialize(horizon_days: 30)
    @horizon_days = horizon_days
  end

  def run
    # key => { description:, total_needed:, product: }
    requirements = {}

    open_production_order_components.each do |comp|
      quantity = comp.quantity || 0
      next if quantity <= 0

      product    = comp.product ||
                   Product.find_by(id: comp.part_number.presence) ||
                   Product.find_by(name: comp.description.presence)
      key        = product&.id || comp.part_number.presence || comp.description.presence
      next if key.nil?

      if requirements[key]
        requirements[key][:total_needed] += quantity
      else
        requirements[key] = {
          description:  comp.description.presence || product&.name || key,
          total_needed: quantity,
          product:      product
        }
      end
    end

    requirements.map do |_key, data|
      product      = data[:product]
      total_needed = data[:total_needed]
      available    = product ? product.available_stock : 0
      shortfall    = [total_needed - available, 0].max
      vendor       = product ? PurchaseOrder.joins(:vendor).where(product: product)
                                 .order(created_at: :desc).first&.vendor : nil
      lead_time    = vendor&.lead_time_days
      order_by_date = lead_time ? Date.today + lead_time.days : nil

      Requirement.new(
        product:         product,
        description:     data[:description],
        total_needed:    total_needed,
        available_stock: available,
        shortfall:       shortfall,
        vendor:          vendor,
        lead_time_days:  lead_time,
        order_by_date:   order_by_date,
        urgent:          shortfall > 0
      )
    end.sort_by { |r| [r.urgent ? 0 : 1, r.description.to_s] }
  end

  private

  def open_production_order_components
    ProductionOrderComponent
      .joins(:production_order)
      .where(production_orders: { status: %w[pending in_progress] })
      .includes(:product)
  end
end
