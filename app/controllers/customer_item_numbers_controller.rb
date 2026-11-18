# Customer part numbers, kept on the customer page.
class CustomerItemNumbersController < ApplicationController
  permission_area :sales, feature: :customers
  before_action :set_customer

  def create
    number = build_number
    return redirect_to(@customer, alert: t('.no_product', id: number.product_id)) unless number.product

    if number.save
      redirect_to @customer, notice: t('.saved', number: number.part_number, item: number.product_id)
    else
      redirect_to @customer, alert: number.errors.full_messages.to_sentence
    end
  end

  def destroy
    @customer.customer_item_numbers.find(params[:id]).destroy!
    redirect_to @customer, notice: t('.removed')
  end

  private

  def build_number
    @customer.customer_item_numbers.find_or_initialize_by(product_id: params[:product_id].to_s.strip).tap do |number|
      number.assign_attributes(part_number: params[:part_number].to_s.strip, description: params[:description].presence)
    end
  end

  def set_customer
    @customer = Customer.find(params[:customer_id])
  end
end
