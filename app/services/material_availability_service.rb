class MaterialAvailabilityService
  Result = Struct.new(:product, :needed, :available, :status, keyword_init: true)

  def initialize(production_order)
    @order = production_order
  end

  # Returns array of Result structs, one per BOM component
  def check
    components = @order.production_order_components.includes(:product).select { |c| c.product_id.present? }
    return [] if components.empty?

    components.map do |comp|
      product   = comp.product
      needed    = comp.quantity || 0
      available = product&.available_stock || 0
      status    = if product.nil?
                    :unknown
                  elsif available >= needed
                    :ok
                  elsif product.current_stock >= needed
                    :low       # enough total stock but cuts into safety stock
                  else
                    :short     # genuinely insufficient
                  end

      Result.new(product: product, needed: needed, available: available, status: status)
    end
  end

  def all_ok?
    check.all? { |r| r.status == :ok }
  end

  def any_short?
    check.any? { |r| r.status == :short }
  end
end
