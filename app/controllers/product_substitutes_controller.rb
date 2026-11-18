# An item's approved substitutes, added and removed on the product page.
class ProductSubstitutesController < ApplicationController
  permission_area :inventory, feature: :products
  before_action :set_product

  def create
    substitute = @product.product_substitutes.new(substitute_params)
    substitute.priority = @product.product_substitutes.maximum(:priority).to_i + 1
    if substitute.save
      redirect_to @product, notice: t('.added', item: substitute.substitute_id)
    else
      redirect_to @product, alert: substitute.errors.full_messages.to_sentence
    end
  end

  def destroy
    @product.product_substitutes.find(params[:id]).destroy!
    redirect_to @product, notice: t('.removed')
  end

  private

  def set_product
    @product = Product.find(params[:product_id])
  end

  def substitute_params
    params.permit(:substitute_id, :ratio, :notes).tap { |p| p[:substitute_id] = p[:substitute_id].to_s.strip }
  end
end
