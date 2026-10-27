class ReportingGroupsController < ApplicationController
  permission_area :accounting
  before_action :set_reporting_group, only: %i[update destroy]

  def index
    groups = ReportingGroup.ordered.includes(:product_cost_lines)
    @groups_by_type = ReportingGroup::ITEM_TYPES.keys.index_with { |type| groups.select { |g| g.item_type == type } }
    @product_counts = Product.where.not(category: [nil, '']).group(:category).count
  end

  # Only non-inventory groups are added by hand; fuel and warehouse groups come from PDI categories.
  def create
    @new_group = ReportingGroup.new(reporting_group_params.merge(item_type: 'non_inventory'))
    @new_group.position = ReportingGroup.maximum(:position).to_i + 1
    save_and_redirect(@new_group, t('.created', name: @new_group.name))
  end

  def update
    @reporting_group.assign_attributes(reporting_group_params)
    save_and_redirect(@reporting_group, t('.updated', name: @reporting_group.name))
  end

  def destroy
    if @reporting_group.destroy
      redirect_to reporting_groups_path, notice: t('.deleted', name: @reporting_group.name)
    else
      redirect_to reporting_groups_path, alert: @reporting_group.errors.full_messages.to_sentence
    end
  end

  private

  def set_reporting_group
    @reporting_group = ReportingGroup.find(params[:id])
  end

  def reporting_group_params
    params.require(:reporting_group)
          .permit(:name, :item_type, :costing_method, :gl_account, :temp_gl_account, :labor, :post_inventory_gl,
                  *ReportingGroup::INVENTORY_ACCOUNT_COLUMNS)
  end

  def save_and_redirect(group, notice)
    if group.save
      redirect_to reporting_groups_path, notice: notice
    else
      redirect_to reporting_groups_path, alert: "#{group.name}: #{group.errors.full_messages.to_sentence}"
    end
  end
end
