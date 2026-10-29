# Manual freight charges on a customer order (warehouse goods, one-off carrier quotes). A sale charge can be
# entered as a markup on the order's purchase freight instead of an amount.
class OrderFreightChargesController < ApplicationController
  permission_area :sales
  before_action :set_order

  def create
    charge = @order.order_freight_charges.build(charge_params.except(:markup_percent))
    apply_markup(charge)
    if charge.save
      Freight::OrderPayables.sync!(@order)
      redirect_to customer_order_path(@order, anchor: 'freight'), notice: t('.created')
    else
      redirect_to customer_order_path(@order, anchor: 'freight'), alert: charge.errors.full_messages.to_sentence
    end
  end

  def destroy
    @order.order_freight_charges.find(params[:id]).destroy!
    Freight::OrderPayables.sync!(@order)
    redirect_to customer_order_path(@order, anchor: 'freight'), notice: t('.deleted')
  end

  private

  def set_order
    @order = CustomerOrder.find(params[:customer_order_id])
  end

  # Sale at cost + markup: the purchase freight on the order × (1 + markup %), when no amount was typed.
  def apply_markup(charge)
    markup = charge_params[:markup_percent].presence
    return unless charge.side == 'sale' && markup && charge.amount.blank?

    charge.mark_up(@order.order_freight_charges.purchase.sum(:amount), markup.to_d)
  end

  def charge_params
    params.require(:order_freight_charge).permit(:side, :charge_type, :description, :carrier_id, :amount,
                                                 :markup_percent)
  end
end
