class InventoryTransactionsController < ApplicationController
  permission_area :inventory
  def index
    @transactions = InventoryTransaction.includes(:product, :created_by, :location)
    @transactions = @transactions.where(location_id: current_warehouse.id) if current_warehouse

    if params[:product_id].present?
      @product = Product.find_by(id: params[:product_id])
      @transactions = @transactions.where(product_id: params[:product_id]) if @product
    end
    @movement_type = params[:movement_type].presence_in(InventoryTransaction::MOVEMENT_TYPES.keys)
    @transactions = @transactions.where(movement_type: @movement_type) if @movement_type

    @transactions = @transactions.order(Arel.sql('COALESCE(occurred_on, created_at::date) DESC'), id: :desc).limit(200)
    @products = Product.order(:name)
  end
end
