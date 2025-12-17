class ProductionOrdersController < ApplicationController
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
    @production_order = ProductionOrder.new(due_date: Date.today, status: "pending")
    12.times { |i| @production_order.production_order_components.build(position: i + 1) }
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
        missing = 12 - @production_order.production_order_components.size
        missing.times { |i| @production_order.production_order_components.build(position: @production_order.production_order_components.size + i + 1) } if missing.positive?
    end

  # PATCH/PUT /production_orders/:id
    def update
    if @production_order.update(production_order_params)
        redirect_to production_order_path(@production_order),
                    notice: "Production order updated."
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

  def safe_date(str)
    return nil if str.blank?
    Date.parse(str) rescue nil
    end

  def set_production_order
    @production_order = ProductionOrder.find(params[:id])
  end

    def production_order_params
    params.require(:production_order).permit(
        :product_id,
        :customer_id,
        :location_id,
        :batch_number,
        :qty_to_make,
        :due_date,
        :status,
        :priority,
        :production_notes,
        :date_started,
        :date_completed,
        :total_qty_produced,
        :filled_by,
        :approved_by,
        production_order_components_attributes: [:id, :position, :quantity, :uom, :part_number, :description, :confirmed_by, :_destroy]
    )
    end


end
