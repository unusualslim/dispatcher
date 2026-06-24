require 'csv'

class PurchaseOrdersController < ApplicationController
  before_action :require_admin!
  before_action :set_purchase_order, only: [:show, :approve, :submit, :receive]

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

  PDI_SITE_ID = 2

  def export_pdi
    pos = PurchaseOrder.includes(:product, :vendor)
                       .where(status: %w[approved submitted])
                       .order(:id)

    csv = CSV.generate do |out|
      pos.each do |po|
        vendor     = po.vendor
        product    = po.product
        today      = Date.today.strftime('%-m/%-d/%Y')
        delivery   = (po.expected_delivery_date || Date.today).strftime('%-m/%-d/%Y')
        total      = po.total_cost&.to_f || 0

        out << ['REM', 'Vendor ID', 'PO Number', 'Business Date', 'Order Date', 'Delivery Date', '', '', '', '', '', '', 'Invoice Total']
        out << ['POH', vendor.id, '', today, today, delivery, '', '', '', '', '', '', total]
        out << ['REM', 'Site ID', 'Product ID', 'Package Code', '', '', 'Inventory Package Qty', 'Invoice Qty', 'Delivery qty', '', 'Billing Units Costs', '', '']
        out << ['POD', PDI_SITE_ID, product&.id, product&.pdi_package_code, '', '', po.quantity.to_f, po.quantity.to_f, '', '', po.unit_cost&.to_f, '', '']
      end
    end

    send_data csv,
              type:        'text/csv; charset=utf-8',
              disposition: "attachment; filename=\"PDI_PO_Export_#{Date.today}.csv\""
  end

  def approve
    @purchase_order.approve!(current_user)
    redirect_to @purchase_order, notice: 'Purchase order approved.'
  end

  def submit
    @purchase_order.update!(status: 'submitted', submitted_at: Time.current)
    redirect_to @purchase_order, notice: 'Purchase order submitted — PDI export queued.'
  rescue => e
    redirect_to @purchase_order, alert: "Could not submit: #{e.message}"
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
