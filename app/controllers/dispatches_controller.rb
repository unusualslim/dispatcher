class DispatchesController < ApplicationController
  before_action :set_dispatch, only: %i[ show edit update destroy ]

  # GET /dispatches or /dispatches.json
  def index
    @dispatches = Dispatch.where.not(status: "deleted")
    @new_dispatches = Dispatch.where(status: "New", driver_id: nil)
    @drivers = User.all
    @workers = User.where(role: "worker")
  end

  # GET /dispatches/1 or /dispatches/1.json
  def show
  end

  # GET /dispatches/new
  def new
    @dispatch = Dispatch.new
    @locations = Location.all
    @recent_customer_orders = CustomerOrder.order(created_at: :desc).limit(5)
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
  
        if @dispatch.driver_id.present? && previous_driver_id != @dispatch.driver_id
          @dispatch.update(status: "Sent to driver")
          
          # Check if the associated user has opted in for emails
          if @dispatch.driver.present? && @dispatch.driver.email_opt_in?
            DispatchMailer.send_dispatch_email(@dispatch).deliver
            puts "EMAIL USERNAME: #{ENV['SENDGRID_USERNAME']}"
            puts "EMAIL PWORD: #{ENV['SENDGRID_PASSWORD']}"
          end
          if @dispatch.driver.present? && @dispatch.driver.sms_opt_in?
            send_text_to_driver(@dispatch.driver.phone_number) if @dispatch.driver.phone_number.present?
            puts "driver phone number: #{@dispatch.driver.phone_number}"
          end
        elsif @dispatch.driver_id.blank? && previous_driver_id.present?
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
    @selected_status = params[:status] || @statuses.first # Get selected status or default

    @dispatches = Dispatch.where(status: @selected_status).order(created_at: :desc)
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

  private

    def boot_twilio
      account_sid = ENV['TWILIO_SID']
      auth_token = ENV['TWILIO_TOKEN']

      @client = Twilio::REST::Client.new account_sid, auth_token
    end

    def send_text_to_driver(driver_phone_number)
      boot_twilio
      @client.messages.create(
        from: ENV['TWILIO_NUMBER'],
        to: driver_phone_number,
        body: "You have been assigned a new dispatch. Check your Dispatcher app for details."
      )
    end

    def update_destination_from_customer_orders(dispatch)
      if dispatch.customer_orders.any?
        first_customer_order = dispatch.customer_orders.first
        location_name = Location.find(first_customer_order.location_id).name
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
