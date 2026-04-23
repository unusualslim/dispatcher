class PurchaseOrdersController < ApplicationController
  before_action :set_purchase_order, only: [:show, :approve, :receive]

  def index
    @purchase_orders = PurchaseOrder.includes(:product, :vendor)
                                    .order(created_at: :desc)
  end

  def new
    @purchase_order = PurchaseOrder.new(product_id: params[:product_id])
    @products = Product.order(:name)
    @vendors  = Vendor.order(:name)
  end

  def create
    @purchase_order = PurchaseOrder.new(purchase_order_params)
    @purchase_order.status = 'draft'
    @purchase_order.trigger_type = 'manual' if @purchase_order.trigger_type.blank?

    if @purchase_order.save
      redirect_to purchase_orders_path, notice: 'Purchase order created.'
    else
      @products = Product.order(:name)
      @vendors  = Vendor.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  def approve
    @purchase_order.approve!(current_user)
    redirect_to @purchase_order, notice: 'Purchase order approved.'
  end

  def receive
    @purchase_order.mark_received!(current_user)
    redirect_to @purchase_order, notice: "Received #{@purchase_order.quantity} #{@purchase_order.product.unit_of_measurement}. Stock updated."
  rescue => e
    redirect_to @purchase_order, alert: "Could not mark received: #{e.message}"
  end

  private

  def set_purchase_order
    @purchase_order = PurchaseOrder.includes(:product, :vendor).find(params[:id])
  end

  def purchase_order_params
    params.require(:purchase_order).permit(
      :product_id, :vendor_id, :quantity, :unit_cost,
      :trigger_type, :notes, :expected_delivery_date
    )
  end
end
