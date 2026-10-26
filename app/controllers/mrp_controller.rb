# Time-phased MRP (Mrp::Plan): when each product runs out, why, and what to order or produce by when.
class MrpController < ApplicationController
  permission_area :purchasing

  HORIZONS = [30, 60, 90].freeze

  def index
    @horizon = horizon
    @result = Mrp::Plan.new(horizon_days: @horizon).run
    @draft_pos   = PurchaseOrder.includes(:vendor, line_items: :product).draft.order(created_at: :desc)
    @pending_pos = PurchaseOrder.includes(:vendor, line_items: :product).pending_approval.order(created_at: :desc)
  end

  # One product's projected stock, day by day.
  def product
    @horizon = horizon
    @plan = Mrp::Plan.new(horizon_days: @horizon).run.plans[params[:product_id]]
    redirect_to mrp_path(horizon: @horizon), alert: t('.not_planned') unless @plan
  end

  def update_settings
    AppSetting::MRP_KEYS.each do |key|
      AppSetting.set(key, params[key].to_i.clamp(0, 365)) if params[key].present?
    end
    redirect_to mrp_path(horizon: horizon), notice: t('.saved')
  end

  private

  def horizon
    HORIZONS.include?(params[:horizon].to_i) ? params[:horizon].to_i : 60
  end
end
