class CustomerOrdersController < ApplicationController

    def index
      @view = params[:view] || 'card' # Default to card view if no view is specified
    
      # Start with including necessary associations for performance
      @customer_orders = CustomerOrder.includes(:location, customer_order_products: :product)
    
      # Apply filters if any
      if params[:product].present?
        @customer_orders = @customer_orders.joins(customer_order_products: :product)
                                          .where('products.name ILIKE ?', "%#{params[:product]}%")
      end
    
      if params[:location].present?
        if params[:location].to_i.to_s == params[:location]  # If it's a number, assume it's an ID
          @customer_orders = @customer_orders.where(location_id: params[:location])
        else
          @customer_orders = @customer_orders.joins(:location)
                                            .where('locations.city ILIKE ?', "%#{params[:location]}%")
        end
      end
    
      if params[:freight_only].present?
        @customer_orders = @customer_orders.where(freight_only: true)
      end
    
      # Apply sorting logic based on the selected option
      case params[:sort_by]
      when 'newest'
        @customer_orders = @customer_orders.order(created_at: :desc) # Sort by date created (newest first)
      when 'oldest'
        @customer_orders = @customer_orders.order(created_at: :asc) # Sort by date created (oldest first)
      when 'required_delivery_date'
        @customer_orders = @customer_orders.order(required_delivery_date: :asc) # Sort by required delivery date (closest first)
      else
        # Default sorting by required_delivery_date (ascending)
        @customer_orders = @customer_orders.order(required_delivery_date: :asc)
      end
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
    def customer_order_params
      params.require(:customer_order).permit(:required_delivery_date, :product, :freight_only, :customer_id, :location_id, :approximate_product_amount, :notes, :order_status, customer_order_products_attributes: [:id, :product_id, :quantity, :price, :_destroy], thing_ids: [])
    end
end
