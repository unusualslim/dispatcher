class WorkOrdersController < ApplicationController
  before_action :set_work_order, only: %i[show edit update destroy]

  def index
    @work_orders = WorkOrder.all
  end

  def show; end

  def new
    @work_order = WorkOrder.new
  end

  def create
    @work_order = WorkOrder.new(work_order_params)
    if @work_order.save
      redirect_to @work_order, notice: 'Work order was successfully created.'
    else
      render :new
    end
  end

  def edit; end

  def update
    if @work_order.update(work_order_params)
      redirect_to @work_order, notice: 'Work order was successfully updated.'
    else
      render :edit
    end
  end

  def destroy
    @work_order.destroy
    redirect_to work_orders_url, notice: 'Work order was successfully destroyed.'
  end

  private

  def set_work_order
    @work_order = WorkOrder.find(params[:id])
  end

  def work_order_params
    params.require(:work_order).permit(:subject, :location_id, :assigned_to, :attachments, :vendor_id, :status, :description, :asset_id)
  end
end