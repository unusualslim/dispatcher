class InventoryAdjustmentsController < ApplicationController
  before_action :require_admin!
  REASON_CODES = [
    'Count Correction',
    'Spill / Loss',
    'Sample / QC Draw',
    'Manual Receipt',
    'Damaged Goods',
    'Transfer In',
    'Transfer Out',
    'Other'
  ].freeze

  def new
    @products = Product.order(:name)
    @reason_codes = REASON_CODES
    @selected_product = Product.find_by(id: params[:product_id])
  end

  def create
    product = Product.find(params[:product_id])
    direction = params[:direction]
    quantity  = params[:quantity].to_d
    reason    = params[:reason_code]
    notes     = [reason, params[:notes].presence].compact.join(' — ')

    if quantity <= 0
      redirect_to new_inventory_adjustment_path(product_id: product.id),
                  alert: "Quantity must be greater than zero."
      return
    end

    ActiveRecord::Base.transaction do
      InventoryTransaction.create!(
        product:          product,
        quantity:         quantity,
        direction:        direction,
        reference_number: "ADJ-#{Time.current.strftime('%Y%m%d%H%M%S')}",
        notes:            notes,
        created_by_id:    current_user.id
      )

      if direction == 'in'
        product.increment!(:current_stock, quantity)
      else
        product.decrement!(:current_stock, quantity)
      end
    end

    redirect_to inventory_transactions_path(product_id: product.id),
                notice: "#{direction == 'in' ? 'Added' : 'Removed'} #{quantity} #{product.unit_of_measurement} #{direction == 'in' ? 'to' : 'from'} #{product.name}."
  rescue => e
    redirect_to new_inventory_adjustment_path(product_id: params[:product_id]),
                alert: "Adjustment failed: #{e.message}"
  end
end
