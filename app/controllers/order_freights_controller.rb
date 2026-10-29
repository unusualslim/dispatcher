# The freight card on a customer order: saves the freight inputs (origin, carrier, miles, extra stops, pump offs,
# how the customer sees freight) and recalculates the charges from the freight rules.
class OrderFreightsController < ApplicationController
  permission_area :sales
  before_action :set_order

  def update
    if @order.update(freight_params)
      result = Freight::Calculator.new(@order).apply! if params[:recalculate].present?
      redirect_to customer_order_path(@order, anchor: 'freight'), **flash_for(result, t('.saved'))
    else
      redirect_to customer_order_path(@order, anchor: 'freight'), alert: @order.errors.full_messages.to_sentence
    end
  end

  def calculate
    result = Freight::Calculator.new(@order).apply!
    redirect_to customer_order_path(@order, anchor: 'freight'), **flash_for(result, t('.calculated'))
  end

  private

  def set_order
    @order = CustomerOrder.find(params[:customer_order_id])
  end

  def flash_for(result, message)
    return { notice: message } unless result
    return { notice: t('.calculated_count', count: result.charges.size) } if result.warnings.empty?

    { alert: ([t('.calculated_count', count: result.charges.size)] + result.warnings).join(' ') }
  end

  def freight_params
    params.require(:customer_order).permit(:freight_origin_location_id, :freight_carrier_id, :freight_miles,
                                           :freight_extra_stops, :freight_pump_offs, :freight_presentation)
  end
end
