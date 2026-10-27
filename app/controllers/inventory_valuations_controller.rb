class InventoryValuationsController < ApplicationController
  permission_area :inventory
  before_action :require_admin!, only: :opening

  def show
    @as_of = parse_date(params[:as_of]) || Date.current
    @from = parse_date(params[:from]) || @as_of.beginning_of_month
    @valuation = InventoryValuation.new(as_of: @as_of, location_id: params[:location_id], group_name: params[:group])
    @start_date = InventoryRevaluation.start_date
    load_filter_options
  end

  # One-time: values today's stock at each product's basis and starts costed tracking (and sales).
  def opening
    InventoryRevaluation.opening!(user: current_user)
    redirect_to inventory_valuation_path, notice: t('.done')
  rescue ArgumentError => e
    redirect_to inventory_valuation_path, alert: e.message
  end

  private

  def load_filter_options
    @locations = Location.where(id: LocationProduct.select(:location_id)).order(:company_name)
    @groups = ReportingGroup.where.not(item_type: 'non_inventory').ordered
  end

  def parse_date(value)
    Date.iso8601(value) if value.present?
  rescue Date::Error
    nil
  end
end
