class DispatchesController < ApplicationController
  before_action :set_dispatch, only: %i[show edit update destroy mark_as_complete mark_as_billed]

  # GET /dispatches or /dispatches.json
  def index
    # Collect filter parameters, setting default for status
    @completed_dispatches = Dispatch.where(status: ["Complete", "complete"]).order(dispatch_date: :desc)
    @filtered_dispatches = Dispatch.where(status: ['New', 'sent_to_driver', 'Sent to driver', 'Sent to Driver']).order(:dispatch_date)
    @destination_locations = Location.all
    @origin_locations = Location.all
    @on_hold_orders = CustomerOrder.where(order_status: "On Hold")
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
      .where(order_status: ['New', 'On Hold'])
      .where.not(order_status: ['complete'])
      .order(created_at: :desc)
    @origin_locations = Location.where(location_category_id: 1)
  end  

  # GET /dispatches/1/edit
  def edit
    @dispatch = Dispatch.find(params[:id])
    @locations = Location.all
    @recent_customer_orders = CustomerOrder
    .where.not(order_status: ['complete'])
    .order(created_at: :desc)
    @origin_locations = Location.where(location_category_id: 1)
  end

  # POST /dispatches or /dispatches.json
  def create
    @origin_locations = Location.where(location_category_id: 1)
    @recent_customer_orders = CustomerOrder
    .where.not(order_status: ['complete'])
    .order(created_at: :desc)
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
    @dispatch = Dispatch.find(params[:id])
    previous_driver_id = @dispatch.driver_id
  
    # Check if new files are uploaded and append them instead of replacing
    if params[:dispatch][:files].present?
      @dispatch.files.attach(params[:dispatch][:files])
    end
  
    respond_to do |format|
      if @dispatch.update(dispatch_params.except(:files)) # Exclude :files to prevent overwrite
        update_destination_from_customer_orders(@dispatch)
  
        if @dispatch.driver_id.blank? && previous_driver_id.present?
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
    @selected_driver = params[:driver] # Selected driver ID
    @sort_by = params[:sort_by] || 'dispatch_date' # Default sorting by dispatch date
  
    # Filter by selected status
    @dispatches = Dispatch.all
    if @selected_status == 'exclude_complete_deleted'
      @dispatches = @dispatches.where.not(status: ['complete', 'deleted'])
    elsif @selected_status != 'all'
      @dispatches = @dispatches.where(status: @selected_status)
    end
  
    # Filter by selected driver (if any)
    if @selected_driver.present?
      @dispatches = @dispatches.where(driver_id: @selected_driver)
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

  def mark_as_complete
    if @dispatch.update(status: "Complete")
      redirect_to dispatch_path(@dispatch), notice: "Dispatch marked as complete."
    else
      redirect_to dispatch_path(@dispatch), alert: "Failed to mark dispatch as complete."
    end
  end

  def mark_as_billed
    if @dispatch.update(status: "Billed")
      redirect_to dispatch_path(@dispatch), notice: "Dispatch marked as billed."
    else
      redirect_to dispatch_path(@dispatch), alert: "Failed to mark dispatch as billed."
    end
  end

  def mark_as_sent_to_driver
    @dispatch = Dispatch.find(params[:id])
    
    if @dispatch.update(status: "Sent to Driver")
      redirect_to dispatch_path(@dispatch), notice: "Dispatch marked as Sent to Driver."
    else
      redirect_to dispatch_path(@dispatch), alert: "Failed to update dispatch status."
    end
  end

  def destroy_file
    @dispatch = Dispatch.find_by(id: params[:dispatch_id]) # Use find_by to avoid an exception
    return redirect_to dispatches_path, alert: "Dispatch not found." unless @dispatch
  
    file = @dispatch.files.find_by(id: params[:id]) # Use find_by to avoid an exception
    return redirect_to dispatch_path(@dispatch), alert: "File not found." unless file
  
    file.purge # Deletes the file from Active Storage
    redirect_to dispatch_path(@dispatch), notice: "File was successfully deleted."
  end
  

  private

    def boot_twilio
      account_sid = ENV['TWILIO_SID']
      auth_token = ENV['TWILIO_TOKEN']

      @client = Twilio::REST::Client.new account_sid, auth_token
    end

    def send_text_to_driver(dispatch, sms_message)
      boot_twilio # Ensure Twilio client is initialized correctly.
    
      # Default product and amount values.
      product = "N/A"
      amount = "N/A"
    
      # Populate product and amount based on customer orders.
      if dispatch.customer_orders.size == 1
        product = dispatch.customer_orders.first.product
        amount = dispatch.customer_orders.first.approximate_product_amount
      elsif dispatch.customer_orders.size > 1
        product = dispatch.customer_orders.map(&:product).join(", ")
        amount = dispatch.customer_orders.map(&:approximate_product_amount).join(", ")
      end
    
      # Construct the SMS body.
      sms_body = sms_message.presence || <<~SMS
        You have been assigned a new dispatch.
        Dispatch ID: #{dispatch.id}
        Origin: #{dispatch.origin}
        Destination: #{dispatch.destination}
        Product: #{product}
        Amount: #{amount} gal
        Notes: #{dispatch.notes}
      SMS
    
      begin
        # Send the SMS.
        sms = @client.messages.create(
          from: ENV['TWILIO_NUMBER'],
          to: dispatch.driver.phone_number,
          body: sms_body.strip # Strip unnecessary whitespace from the body.
        )
    
        # Log the SMS in the database.
        DispatchMessage.create!(
          user_id: dispatch.driver.id, # Assuming `dispatch.driver` is a User.
          message_body: sms_body,
          delivery_method: "SMS",
          reference_id: sms.sid,
          status: "sent",
          sent_at: Time.current
        )
      rescue Twilio::REST::RestError => e
        # Log the error and create a failed message record.
        Rails.logger.error("Failed to send SMS: #{e.message}")
    
        DispatchMessage.create!(
          user_id: dispatch.driver.id,
          message_body: sms_body,
          delivery_method: "SMS",
          reference_id: nil,
          status: "failed",
          sent_at: Time.current
        )
      end
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
      params.require(:dispatch).permit(:driver_id, :origin, :destination, :info, :dispatch_date, :status, :notes, :vendor_id, :customer_order_ids => [], files: [])
    end
end
