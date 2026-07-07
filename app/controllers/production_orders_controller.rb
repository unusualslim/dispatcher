class ProductionOrdersController < ApplicationController
  before_action :require_admin!
  before_action :authenticate_user!
  before_action :set_production_order, only: %i[show edit update destroy]

  # GET /production_orders
  # Table view
  def index
    @view = "table"

    @statuses        = ProductionOrder::STATUSES
    @selected_status = params[:status].presence || "all"

    @search_term = params[:q]
    @location    = params[:location]
    @due_from    = params[:due_from]
    @due_to      = params[:due_to]

    @production_orders = ProductionOrder
      .search(@search_term)
      .by_status(@selected_status)
      .by_location(@location)
      .due_between(@due_from, @due_to)
      .ordered_default
  end

  # GET /production_orders/dashboard
  def dashboard
    today = Date.today

    @stats = {
      pending:              ProductionOrder.where(status: 'pending').count,
      in_progress:          ProductionOrder.where(status: 'in_progress').count,
      due_this_week:        ProductionOrder.where(status: %w[pending in_progress])
                              .where(due_date: today..today + 7).count,
      completed_this_month: ProductionOrder.where(status: 'completed')
                              .where('created_at >= ?', today.beginning_of_month).count,
    }

    @open_orders = ProductionOrder
      .where(status: %w[pending in_progress])
      .order(due_date: :asc)
      .includes(:product, :customer, :location)

    @orders_needing_production = production_demand_from_customer_orders

    @finished_goods = Product.finished_goods.order(:name)
  end

  # GET /production_orders/kanban
    def kanban
    @search_term     = params[:search]
    @selected_status = params[:status]
    @location        = params[:location]
    @due_from        = params[:due_from]
    @due_to          = params[:due_to]

    @production_orders =
        ProductionOrder
        .includes(:product)
        .search(@search_term)
        .by_status(@selected_status)
        .by_location(@location)
        .due_between(@due_from, @due_to)
        .ordered_default

    # Use the filter dates to drive the columns (fallback to your default range)
    @start_date = safe_date(@due_from) || Date.yesterday
    @end_date   = safe_date(@due_to)   || (Date.today + 6.days)

    # Safety: don’t allow inverted ranges
    if @start_date > @end_date
        @start_date, @end_date = @end_date, @start_date
    end
    end

  # GET /production_orders/new
  def new
    @production_order = ProductionOrder.new(
      due_date:    params[:due_date].present? ? (Date.parse(params[:due_date]) rescue Date.today) : Date.today,
      status:      "pending",
      product_id:  params[:product_id],
      item:        params[:item],
      qty_to_make: params[:qty_to_make]
    )
    5.times { |i| @production_order.production_order_components.build(position: i + 1) }

    # ✅ ensure the form renders one blank batch row
    @production_order.production_order_batches.build
  end


  # POST /production_orders
  def create
    @production_order = ProductionOrder.new(production_order_params)

    if @production_order.save
      redirect_to kanban_production_orders_path, notice: "Production order created."
    else
      render :new, status: :unprocessable_entity
    end
  end

  # GET /production_orders/:id/edit
  def edit
    missing = 5 - @production_order.production_order_components.size
    missing.times do |i|
      @production_order.production_order_components.build(
        position: @production_order.production_order_components.size + i + 1
      )
    end if missing.positive?

    # ✅ if there are no batches yet, show one blank row
    @production_order.production_order_batches.build if @production_order.production_order_batches.empty?
  end

  def update
    params[:production_order][:location_id] = nil if params[:production_order][:location_id].to_s == "0"
    params[:production_order][:customer_id] = nil if params[:production_order][:customer_id].to_s == "0"
    if @production_order.update(production_order_params)
      respond_to do |format|
        format.html { redirect_to @production_order, notice: "Production order updated." }
        format.turbo_stream { redirect_to @production_order, notice: "Production order updated." }
      end
    else
      render :edit, status: :unprocessable_entity
    end
  end

  # GET /production_orders/:id
  def show; end

  # DELETE /production_orders/:id
    def destroy
    @production_order.destroy
    redirect_to kanban_production_orders_path, notice: "Production order deleted."
    end


  private

  def production_demand_from_customer_orders
    cops = CustomerOrderProduct
      .where(item_type: 'production')
      .where.not(product_id: nil)
      .includes(:product, customer_order: [:customer, :location])

    result = {}
    cops.each do |cop|
      next unless cop.product
      needed    = (cop.quantity || 0).to_f
      in_stock  = cop.product.current_stock.to_f
      shortfall = needed - in_stock
      next unless shortfall > 0

      order = cop.customer_order
      next if order.order_status == 'Deleted'

      result[order.id] ||= { order: order, shortfalls: [] }
      result[order.id][:shortfalls] << {
        product:   cop.product,
        needed:    needed,
        in_stock:  in_stock,
        shortfall: shortfall,
      }
    end

    result.values.sort_by { |r| r[:order].required_delivery_date || Date.new(9999) }
  end

  def safe_date(str)
    return nil if str.blank?
    Date.parse(str) rescue nil
    end

  def set_production_order
    @production_order = ProductionOrder
      .includes(production_order_components: :product)
      .find(params[:id])
  end

  def production_order_params
    params.require(:production_order).permit(
      :product_id,
      :customer_id,
      :location_id,
      :qty_to_make,
      :due_date,
      :production_date,
      :status,
      :priority,
      :production_notes,
      :date_started,
      :date_completed,
      :total_qty_produced,
      :filled_by,
      :approved_by,

      production_order_batches_attributes: [
        :id, :batch_number, :quantity, :qc_status, :qc_notes, :qc_by, :_destroy
      ],

      # ✅ IMPORTANT: this must be EXACTLY this key name
      production_order_components_attributes: [
        :id, :position, :description, :quantity, :uom, :_destroy
      ]
    )
  end
  private :production_order_params
end
