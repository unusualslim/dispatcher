class DispatchesController < ApplicationController
  before_action :set_dispatch, only: %i[ show edit update destroy ]

  # GET /dispatches or /dispatches.json
  def index
    # Collect filter parameters, setting default for status
    @filtered_dispatches = Dispatch.where(status: ['New', 'sent_to_driver', 'Sent to driver']).order(:dispatch_date)
    @destination_locations = Location.all
    @origin_locations = Location.all
    @filters = {
      product: params[:product],
      delivery_date: params[:delivery_date],
      delivery_date_condition: params[:delivery_date_condition],
      location: params[:location],
      amount: params[:amount],
      status: params[:status] || 'unassigned'  # Default to 'unassigned' if not provided
    }
  
    # Base query depending on the selected status
    case @filters[:status]
    when 'unassigned'
      @unassigned_open_orders = CustomerOrder.where(order_status: 'New')
                                             .left_joins(:dispatch_customer_orders)
                                             .where(dispatch_customer_orders: { id: nil })
    when 'assigned'
      @unassigned_open_orders = CustomerOrder.joins(:dispatch_customer_orders).distinct
    else
      @unassigned_open_orders = CustomerOrder.all.distinct
    end
  
    # Apply filters for product
    if @filters[:product].present?
      @unassigned_open_orders = @unassigned_open_orders.where('product LIKE ?', "%#{@filters[:product]}%")
    end
  
    # Apply filters for location
    if @filters[:location].present?
      @unassigned_open_orders = @unassigned_open_orders.joins(:location)
                                                       .where('locations.company_name LIKE ?', "%#{@filters[:location]}%")
    end
  
    # Apply filters for amount
    if @filters[:amount].present?
      @unassigned_open_orders = @unassigned_open_orders.where(approximate_product_amount: @filters[:amount])
    end
  
    # Apply delivery date filter with condition
    if @filters[:delivery_date].present? && @filters[:delivery_date_condition].present?
      delivery_date = @filters[:delivery_date]
      case @filters[:delivery_date_condition]
      when 'before'
        @unassigned_open_orders = @unassigned_open_orders.where("required_delivery_date < ?", delivery_date)
      when 'after'
        @unassigned_open_orders = @unassigned_open_orders.where("required_delivery_date > ?", delivery_date)
      when 'on'
        @unassigned_open_orders = @unassigned_open_orders.where(required_delivery_date: delivery_date)
      end
    end
  
    # Other necessary data for the page
    @new_dispatches = Dispatch.where(status: "New", driver_id: nil)
    @drivers = User.all
    @workers = User.where(role: "worker")
  end
  

  # GET /dispatches/1 or /dispatches/1.json
  def show
    @dispatch = Dispatch.find(params[:id]) 
    @customer_orders = @dispatch.customer_orders
    @origin_locations = Location.where(location_category_id: 1)
    @destination_locations = Location.where(location_category_id: 2)
  end

  # GET /dispatches/new
  def new
    @dispatch = Dispatch.new
    
    # Check if a customer_order_id was passed and set default values based on that
    if params[:customer_order_id]
      customer_order = CustomerOrder.find(params[:customer_order_id])
      
      # Set default values in @dispatch from the customer_order
      @dispatch.customer_order_ids = [customer_order.id]
      @dispatch.origin = customer_order.location.city if customer_order.location
      @dispatch.dispatch_date = Date.today
      
      # Assign for pre-selecting in the form
      @selected_customer_order_id = customer_order.id
    end
    
    # Load data needed for form options
    @locations = Location.all
    @recent_customer_orders = CustomerOrder
      .where.not(order_status: ['complete'])
      .order(created_at: :desc)
      .limit(5)   
    @origin_locations = Location.where(location_category_id: 1)
  end  

  # GET /dispatches/1/edit
  def edit
    @locations = Location.all
    @recent_customer_orders = CustomerOrder.order(created_at: :desc).limit(5)
    @origin_locations = Location.where(location_category_id: 1)
  end

  # POST /dispatches or /dispatches.json
  def create
    @origin_locations = Location.where(location_category_id: 1)
    @recent_customer_orders = CustomerOrder.order(created_at: :desc).limit(5)
    @dispatch = Dispatch.new(dispatch_params)
  
    respond_to do |format|
      if @dispatch.save
        update_destination_from_customer_orders(@dispatch)
        format.html { redirect_to dispatch_url(@dispatch), notice: "Dispatch was successfully created." }
        format.json { render :show, status: :created, location: @dispatch }
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @dispatch.errors, status: :unprocessable_entity }
      end
    end
  end
  

  # PATCH/PUT /dispatches/1 or /dispatches/1.json
  def update
    previous_driver_id = @dispatch.driver_id
  
    respond_to do |format|
      if @dispatch.update(dispatch_params)
        update_destination_from_customer_orders(@dispatch)
  
        if @dispatch.driver_id.blank? && previous_driver_id.present?
          # This condition checks if the dispatch is moved back to the new column from a driver column
          @dispatch.update(status: "New")
        end
  
        format.html { redirect_to dispatch_url(@dispatch), notice: "Dispatch was successfully updated." }
        format.json { render :show, status: :ok, location: @dispatch }
      else
        format.html { render :edit, status: :unprocessable_entity }
        format.json { render json: @dispatch.errors, status: :unprocessable_entity }
      end
    end
  end

  def view_dispatches
    @statuses = Dispatch.distinct.pluck(:status) # Fetch all unique statuses
    @selected_status = params[:status] || 'all' # Default to 'all' to show all statuses
    @sort_by = params[:sort_by] || 'dispatch_date' # Default sorting by dispatch date
  
    # Filter by selected status
    @dispatches = Dispatch.all
    if @selected_status == 'exclude_complete_deleted'
      @dispatches = @dispatches.where.not(status: ['complete', 'deleted'])
    elsif @selected_status != 'all'
      @dispatches = @dispatches.where(status: @selected_status)
    end
  
    # Apply sorting
    @dispatches = case @sort_by
                  when 'newest'
                    @dispatches.order(created_at: :desc)
                  when 'oldest'
                    @dispatches.order(created_at: :asc)
                  when 'dispatch_date'
                    @dispatches.order(dispatch_date: :asc)
                  else
                    @dispatches
                  end
  end  

  def search
    query = params[:query]
    @searched_orders = CustomerOrder.where('id LIKE ?', "%#{query}%")
                                   .or(CustomerOrder.joins(:location).where('locations.name LIKE ?', "%#{query}%"))
                                   .order(created_at: :desc).limit(5)
  end  

  # DELETE /dispatches/1 or /dispatches/1.json
  def destroy
    @dispatch.destroy

    respond_to do |format|
      format.html { redirect_to dispatches_url, notice: "Dispatch was successfully destroyed." }
      format.json { head :no_content }
    end
  end

  def send_notification
    @dispatch = Dispatch.find(params[:id])
    email_message = params[:email_message]
    sms_message = params[:sms_message]
    
    # Update dispatch status to "Sent to driver"
    @dispatch.update(status: "Sent to driver")
  
    # Send email if driver has opted in for email notifications
    if @dispatch.driver.present? && @dispatch.driver.email_opt_in?
      DispatchMailer.send_dispatch_email(@dispatch, email_message).deliver_now
    end
    
    # Send SMS if driver has opted in for SMS notifications and has a phone number
    if @dispatch.driver.present? && @dispatch.driver.sms_opt_in? && @dispatch.driver.phone_number.present?
      send_text_to_driver(@dispatch, sms_message)
    end
  
    # Respond to JS or HTML format
    respond_to do |format|
      format.js { render js: "alert('Notification sent successfully!');" }
      format.html { redirect_to dispatch_path(@dispatch), notice: "Notification sent successfully." }
    end
  end  

  private

    def boot_twilio
      account_sid = ENV['TWILIO_SID']
      auth_token = ENV['TWILIO_TOKEN']

      @client = Twilio::REST::Client.new account_sid, auth_token
    end

    def send_text_to_driver(dispatch, sms_message)
      boot_twilio # Ensure this method correctly initializes Twilio's client.
    
      # Set default values for product and amount
      product = "N/A"
      amount = "N/A"
    
      # If there is only one customer order, use its product and amount
      if dispatch.customer_orders.size == 1
        product = dispatch.customer_orders.first.product
        amount = dispatch.customer_orders.first.approximate_product_amount
      # If there are multiple customer orders, you might want to loop over them
      elsif dispatch.customer_orders.size > 1
        product = dispatch.customer_orders.map(&:product).join(", ") # Joining product names if there are multiple
        amount = dispatch.customer_orders.map(&:approximate_product_amount).join(", ") # Joining amounts if multiple orders exist
      end
    
      # Now send the SMS with the correct product and amount
      @client.messages.create(
        from: ENV['TWILIO_NUMBER'],
        to: dispatch.driver.phone_number,
        body: sms_message || "You have been assigned a new dispatch.\nDispatch ID: #{dispatch.id}\nOrigin: #{dispatch.origin}\nDestination: #{dispatch.destination}\nProduct: #{product}\nAmount: #{amount} gal\nNotes: #{dispatch.notes}"
      )
    end
    
    

    def update_destination_from_customer_orders(dispatch)
      if dispatch.customer_orders.any?
        first_customer_order = dispatch.customer_orders.first
        location_name = Location.find(first_customer_order.location_id).city
        destination_count = dispatch.customer_orders.size - 1
        if destination_count > 0
          dispatch.update(destination: "#{location_name} + #{destination_count}")
        else
          dispatch.update(destination: location_name)
        end
      end
    end

    def set_dispatch
      @dispatch = Dispatch.find(params[:id])
    end

    def dispatch_params
      params.require(:dispatch).permit(:driver_id, :origin, :destination, :info, :dispatch_date, :status, :notes, :customer_order_ids => [])
    end
end
