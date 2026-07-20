require 'csv'

class PurchaseOrdersController < ApplicationController
  before_action :require_admin!
  before_action :set_purchase_order, only: [:show, :approve, :submit, :receive, :post_to_inventory]

  def index
    @status_filter = params[:status].presence
    @status_counts = PurchaseOrder::STATUSES.index_with { |s| PurchaseOrder.where(status: s).count }
    scope = PurchaseOrder.includes(:vendor, :line_items).order(created_at: :desc)
    scope = scope.where(status: @status_filter) if @status_filter
    @purchase_orders = scope
  end

  def new
    @purchase_order = PurchaseOrder.new
    @vendors  = Vendor.order(:name)
    @products = Product.order(:name)

    product_ids = Array(params[:product_ids]).select(&:present?)
    product_ids = [params[:product_id]] if product_ids.empty? && params[:product_id].present?

    if product_ids.any?
      products = Product.where(id: product_ids).index_by(&:id)
      product_ids.each do |pid|
        p = products[pid]
        next unless p
        @purchase_order.line_items.build(
          product_id:   p.id,
          product_name: p.name,
          unit_cost:    p.cost_per_unit,
          package_code: p.pdi_package_code
        )
      end
      @purchase_order.line_items.build if @purchase_order.line_items.empty?
    else
      @purchase_order.line_items.build
    end
  end

  def create
    @purchase_order = PurchaseOrder.new(purchase_order_params)
    @purchase_order.status = 'draft'
    @purchase_order.trigger_type = 'manual' if @purchase_order.trigger_type.blank?

    if @purchase_order.save
      redirect_to purchase_orders_path, notice: 'Purchase order created.'
    else
      @vendors  = Vendor.order(:name)
      @products = Product.order(:name)
      render :new, status: :unprocessable_entity
    end
  end

  def show
  end

  PDI_SITE_ID = 2

  def export_pdi
    pos = PurchaseOrder.includes(:vendor, line_items: :product)
                       .where(status: %w[approved submitted])
                       .order(:id)

    csv = CSV.generate do |out|
      pos.each do |po|
        vendor   = po.vendor
        today    = Date.today.strftime('%-m/%-d/%Y')
        delivery = (po.expected_delivery_date || Date.today).strftime('%-m/%-d/%Y')
        total    = po.total_cost.to_f

        out << ['REM', 'Vendor ID', 'PO Number', 'Business Date', 'Order Date', 'Delivery Date', '', '', '', '', '', '', 'Invoice Total']
        out << ['POH', vendor.id, '', today, today, delivery, '', '', '', '', '', '', total]
        out << ['REM', 'Site ID', 'Product ID', 'Package Code', '', '', 'Inventory Package Qty', 'Invoice Qty', 'Delivery qty', '', 'Billing Units Costs', '', '']
        po.line_items.each do |line|
          out << ['POD', PDI_SITE_ID, line.product_id, line.product&.pdi_package_code || line.package_code,
                  '', '', line.quantity.to_f, line.quantity.to_f, '', '', line.unit_cost&.to_f, '', '']
        end
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
    redirect_to @purchase_order, notice: 'Marked as received. Post to inventory when ready.'
  rescue => e
    redirect_to @purchase_order, alert: "Could not mark received: #{e.message}"
  end

  def post_to_inventory
    if @purchase_order.post_to_inventory!(current_user)
      redirect_to @purchase_order, notice: 'Inventory updated successfully.'
    else
      redirect_to @purchase_order, alert: 'Already posted to inventory.'
    end
  rescue => e
    redirect_to @purchase_order, alert: "Could not post to inventory: #{e.message}"
  end

  private

  def set_purchase_order
    @purchase_order = PurchaseOrder.includes(:vendor, line_items: :product).find(params[:id])
  end

  def purchase_order_params
    params.require(:purchase_order).permit(
      :vendor_id, :trigger_type, :notes, :expected_delivery_date,
      line_items_attributes: [:id, :product_id, :quantity, :unit_cost, :package_code, :_destroy]
    )
  end
end
