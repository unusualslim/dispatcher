class CustomerOrdersController < ApplicationController
  before_action :require_admin!

  def dashboard
    today = Date.today

    @stats = {
      new:                 CustomerOrder.where(order_status: 'New').count,
      due_this_week:       CustomerOrder.where(order_status: 'New')
                             .where(required_delivery_date: today..today + 7).count,
      overdue:             CustomerOrder.where(order_status: 'New')
                             .where('required_delivery_date < ?', today).count,
      complete_this_month: CustomerOrder.where(order_status: 'Complete')
                             .where('created_at >= ?', today.beginning_of_month).count,
    }

    @upcoming = CustomerOrder
      .where(order_status: 'New')
      .where('required_delivery_date >= ?', today)
      .order(required_delivery_date: :asc)
      .includes(:customer, :location)
      .limit(20)

    @orders_needing_production = production_shortfalls

    @last_import = SyncLog.for_process('Customer Order Import').first
  end

def index
  @view = params[:view] || 'card'  # Default to card view

  # Load collections for the selects
  @customers = Customer.order(:name)
  @products  = Product.order(:name)
  @locations = Location.order(:city)

  # Start your query with the necessary includes
  @customer_orders = CustomerOrder
                       .includes(:location, :customer, customer_order_products: :product)

  # Text search: order no, invoice no, customer name, location name
  if params[:q].present?
    q = "%#{params[:q]}%"
    @customer_orders = @customer_orders
                         .left_joins(:customer, :location)
                         .where(
                           'customer_orders.external_order_no ILIKE ? OR
                            customer_orders.invoice_no ILIKE ? OR
                            customers.name ILIKE ? OR
                            locations.company_name ILIKE ?',
                           q, q, q, q
                         )
                         .references(:customer, :location)
  end

  # filter by customer
  if params[:customer_id].present?
    @customer_orders = @customer_orders.where(customer_id: params[:customer_id])
  end

  # filter by product name (via join to products)
  if params[:product].present?
    @customer_orders = @customer_orders
                         .joins(customer_order_products: :product)
                         .where('products.name ILIKE ?', "%#{params[:product]}%")
  end

  # filter by location (ID or city name)
  if params[:location].present?
    if params[:location].to_i.to_s == params[:location]
      @customer_orders = @customer_orders.where(location_id: params[:location])
    else
      @customer_orders = @customer_orders
                           .joins(:location)
                           .where('locations.city ILIKE ?', "%#{params[:location]}%")
    end
  end

  # freight-only flag
  if params[:freight_only].present?
    @customer_orders = @customer_orders.where(freight_only: true)
  end

  # filter by order_status (e.g. "New", "On Hold", "unassigned")
  if params[:order_status].present?
    if params[:order_status] == "unassigned"
      @customer_orders = @customer_orders
                           .left_joins(:dispatch_customer_orders)
                           .where(dispatch_customer_orders: { id: nil })
                           .where(order_status: "New")
    else
      @customer_orders = @customer_orders.where(order_status: params[:order_status])
    end
  end

  # Apply sorting
  case params[:sort_by]
  when 'newest'
    @customer_orders = @customer_orders.order(created_at: :desc)
  when 'oldest'
    @customer_orders = @customer_orders.order(created_at: :asc)
  when 'required_delivery_date'
    @customer_orders = @customer_orders.order(required_delivery_date: :asc)
  else
    @customer_orders = @customer_orders.order(required_delivery_date: :asc)
  end

  @customer_orders = @customer_orders.paginate(page: params[:page], per_page: 25)
end
  
    def show
        @customer_order = CustomerOrder.find(params[:id])
        @locations = Location.where(location_category_id: 2)
    end

    def new
        @customer_order = CustomerOrder.new
    end

    def edit
        @customer_order = CustomerOrder.find(params[:id])
    end

    def create_dispatch
      @customer_order = CustomerOrder.find(params[:id])
    
      # Assign a user and create a dispatch for the order here.
      # Adjust based on your app's logic; e.g., you might create a new Dispatch record.
    
      if @customer_order.assign_user_and_create_dispatch
        redirect_to @customer_order, notice: 'User assigned and dispatch created successfully.'
      else
        redirect_to @customer_order, alert: 'There was an error creating the dispatch.'
      end
    end

    def create
      @location = Location.find(customer_order_params[:location_id])
    
      # Check if the location is disabled
      if @location.disabled?
        respond_to do |format|
          format.html { redirect_to new_customer_order_path, alert: "The selected location is currently disabled and cannot be used." }
          format.json { render json: { error: "The selected location is currently disabled and cannot be used." }, status: :unprocessable_entity }
        end
        return
      end
    
      @customer_order = CustomerOrder.new(customer_order_params)
    
      respond_to do |format|
        if @customer_order.save
          format.html { redirect_to customer_order_url(@customer_order), notice: "Order was successfully created." }
          format.json { render :show, status: :created, location: @customer_order }
        else
          format.html { render :new, status: :unprocessable_entity }
          format.json { render json: @customer_order.errors, status: :unprocessable_entity }
        end
      end
    end

    def update
      @customer_order = CustomerOrder.find(params[:id])
    
      if @customer_order.update(customer_order_params)
        respond_to do |format|
          format.html { redirect_to @customer_order, notice: 'Customer Order was successfully updated.' }
          format.json { render :show, status: :ok, location: @customer_order }
        end
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @customer_order.errors, status: :unprocessable_entity }
      end
    end

    def destroy
      @customer_order = CustomerOrder.find(params[:id])
      @customer_order.destroy
      redirect_to dispatches_path, notice: 'Order was successfully deleted.'
    end

    private

    def production_shortfalls
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

    def customer_order_params
      params.require(:customer_order).permit(:required_delivery_date, :product, :freight_only, :customer_id, :location_id, :approximate_product_amount, :notes, :order_status, customer_order_products_attributes: [:id, :product_id, :quantity, :price, :_destroy], thing_ids: [])
    end
end
