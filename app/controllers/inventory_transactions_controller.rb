class InventoryTransactionsController < ApplicationController
  before_action :require_admin!
  def index
    @transactions = InventoryTransaction.includes(:product, :created_by)

    if params[:product_id].present?
      @product = Product.find_by(id: params[:product_id])
      @transactions = @transactions.where(product_id: params[:product_id]) if @product
    end

    @transactions = @transactions.order(created_at: :desc).limit(200)
    @products = Product.order(:name)
  end
end
