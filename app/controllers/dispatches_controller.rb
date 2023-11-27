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
  end

  # POST /dispatches or /dispatches.json
  def create
    @dispatch = Dispatch.new(dispatch_params)
    customer_order = CustomerOrder.find(params[:dispatch][:customer_order_id])
    @dispatch.destination = customer_order.location.name

    respond_to do |format|
      if @dispatch.save
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
        new_driver_id = @dispatch.driver_id
  
        # Check if the dispatch was unassigned before or the assigned driver has changed
        if (previous_driver_id.nil? && !new_driver_id.nil?) || (previous_driver_id != new_driver_id)
          DispatchMailer.send_dispatch_email(@dispatch).deliver
        end
        
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
    def set_dispatch
      @dispatch = Dispatch.find(params[:id])
    end

    def dispatch_params
      params.require(:dispatch).permit(:driver_id, :origin, :destination, :info, :dispatch_date, :status, :notes, :customer_order_id)
    end
end
