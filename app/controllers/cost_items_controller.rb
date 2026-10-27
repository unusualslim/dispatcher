# Accounting → Cost Items: the non-inventory cost catalog that product cost lines price from.
class CostItemsController < ApplicationController
  permission_area :accounting
  before_action :set_cost_item, only: %i[update destroy]

  def index
    @groups = ReportingGroup.non_inventory.ordered
    @items_by_group = CostItem.includes(:reporting_group).ordered.group_by(&:reporting_group_id)
    @line_counts = ProductCostLine.where.not(cost_item_id: nil).group(:cost_item_id).count
  end

  def create
    save_and_redirect(CostItem.new(cost_item_params), t('.created', name: cost_item_params[:name]))
  end

  def update
    @cost_item.assign_attributes(cost_item_params)
    save_and_redirect(@cost_item, t('.updated', name: @cost_item.name))
  end

  def destroy
    if @cost_item.destroy
      redirect_to cost_items_path, notice: t('.deleted', name: @cost_item.name)
    else
      redirect_to cost_items_path, alert: @cost_item.errors.full_messages.to_sentence
    end
  end

  private

  def set_cost_item
    @cost_item = CostItem.find(params[:id])
  end

  def cost_item_params
    params.require(:cost_item).permit(:name, :reporting_group_id, :unit_cost, :unit, :vendor, :effective_date, :notes,
                                      :active)
  end

  def save_and_redirect(item, notice)
    if item.save
      redirect_to cost_items_path, notice: notice
    else
      redirect_to cost_items_path, alert: "#{item.name}: #{item.errors.full_messages.to_sentence}"
    end
  end
end
