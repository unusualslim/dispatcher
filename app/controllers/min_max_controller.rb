# Purchasing → Min/Max: suggested safety stock, min and max from 12 months' usage and the turns target
# (MinMaxPlanner). Ticked rows are applied to the products; nothing changes on its own.
class MinMaxController < ApplicationController
  permission_area :purchasing, features: { apply: :inventory_pos, update_settings: :inventory_pos }

  SHOWS = { 'changed' => 'Suggestions that differ', 'all' => 'All planned items', 'unused' => 'No usage' }.freeze

  def index
    @show = SHOWS.key?(params[:show]) ? params[:show] : 'changed'
    @group = params[:group].presence
    rows = planned_rows
    @counts = SHOWS.keys.index_with { |key| filter(rows, key).size }
    @rows = filter(rows, @show)
  end

  def apply
    count = MinMaxPlanner.new.apply!(Array(params[:product_ids]))
    redirect_to min_max_path(show: params[:show], group: params[:group]), notice: t('.applied', count: count)
  end

  def update_settings
    MinMaxPlanner::SETTINGS.each_key do |key|
      AppSetting.set(key, params[key].to_i.clamp(1, 100)) if params[key].present?
    end
    redirect_to min_max_path, notice: t('.saved')
  end

  private

  def planned_rows
    rows = MinMaxPlanner.new.rows
    @group ? rows.select { |r| r.product.category == @group } : rows
  end

  def filter(rows, key)
    case key
    when 'changed' then rows.select(&:changed?)
    when 'unused' then rows.reject(&:safety)
    else rows
    end
  end
end
