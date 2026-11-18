# A product's vendor prices (several per vendor: part number, package or quantity break, cost), added and removed
# on the product page's Vendors card.
class VendorItemPricesController < ApplicationController
  permission_area :inventory, feature: :products
  before_action :set_product

  def create
    link = @product.product_vendors.find(params[:product_vendor_id])
    price = link.prices.new(price_params)
    if price.save
      redirect_to @product, notice: t('.added', vendor: link.vendor.name)
    else
      redirect_to @product, alert: price.errors.full_messages.to_sentence
    end
  end

  def destroy
    VendorItemPrice.joins(:product_vendor).where(product_vendors: { product_id: @product.id })
                   .find(params[:id]).destroy!
    redirect_to @product, notice: t('.removed')
  end

  private

  def price_params
    params.permit(:vendor_part_number, :description, :min_quantity, :unit_cost, :effective_on)
  end

  def set_product
    @product = Product.find(params[:product_id])
  end
end
