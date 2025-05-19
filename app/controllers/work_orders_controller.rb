class WorkOrdersController < ApplicationController
  before_action :set_work_order, only: %i[show edit update destroy]

  def index
    @work_orders = WorkOrder.all
  end

  def show
    @work_order = WorkOrder.find(params[:id])
  end

  def new
    @work_order = WorkOrder.new
  end

  def create
    @work_order = WorkOrder.new(work_order_params)
    if @work_order.save
      # Send email to the assigned user
      if @work_order.assigned_to.present?
        user = User.find_by(id: @work_order.assigned_to)
        DispatchMailer.send_work_order_email(@work_order, "A new work order has been assigned to you.").deliver_later
      end
  
      redirect_to @work_order, notice: 'Work order was successfully created.'
    else
      render :new
    end
  end

  def edit; end

  def update
    if @work_order.update(work_order_params)
      # Send email to the assigned user
      if @work_order.assigned_to.present?
        user = User.find_by(id: @work_order.assigned_to)
        DispatchMailer.send_work_order_email(@work_order, "The work order assigned to you has been updated.").deliver_later
      end
  
      redirect_to @work_order, notice: 'Work order was successfully updated.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @work_order.destroy
    redirect_to work_orders_url, notice: 'Work order was successfully destroyed.'
  end

  def workables
    locations = Location.select(:id, :company_name).map { |l| { id: l.id, name: l.company_name, type: "Location" } }
    things = Thing.select(:id, :name).map { |t| { id: t.id, name: t.name, type: "Thing" } }
  
    if params[:query].present?
      query = params[:query].downcase
      locations = locations.select { |l| l[:name].downcase.include?(query) }
      things = things.select { |t| t[:name].downcase.include?(query) }
    else
      # Limit the initial results to avoid a long list
      locations = locations.first(4)
      things = things.first(4)
    end
  
    workables = locations + things
    render json: workables
  end

  private

  def set_work_order
    @work_order = WorkOrder.find(params[:id])
  end

  def work_order_params
    params.require(:work_order).permit(:subject, :location_id, :assigned_to, :attachments, :vendor_id, :status, :description, :asset_id, :workable_id, :workable_type)
  end
end