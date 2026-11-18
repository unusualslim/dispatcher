# Scrap recorded on a production order (its Scrap card): what was scrapped, how much and why.
class ProductionOrderScrapsController < ApplicationController
  permission_area :production
  before_action :set_order

  def create
    return redirect_to(@order, alert: t('.voided')) if @order.voided?

    scrap = @order.production_order_scraps.new(scrap_params.merge(recorded_by: current_user))
    if scrap.save
      redirect_to @order, notice: recorded_notice(scrap)
    else
      redirect_to @order, alert: scrap.errors.full_messages.to_sentence
    end
  end

  def destroy
    @order.production_order_scraps.find(params[:id]).destroy!
    redirect_to @order, notice: t('.removed')
  end

  private

  def recorded_notice(scrap)
    t('production_order_scraps.create.recorded', quantity: scrap.quantity.to_d.to_s('F'),
                                                 reason: scrap.scrap_reason.name)
  end

  def set_order
    @order = ProductionOrder.find(params[:production_order_id])
  end

  def scrap_params
    params.expect(production_order_scrap: %i[scrap_reason_id product_id quantity notes])
  end
end
