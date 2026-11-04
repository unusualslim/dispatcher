class InventoryValuationsController < ApplicationController
  permission_area :inventory
  before_action :require_admin!, only: %i[opening reset_tracking replay]
  before_action :require_reset_allowed!, only: :reset_tracking

  def show
    @as_of = parse_date(params[:as_of]) || Date.current
    @from = parse_date(params[:from]) || @as_of.beginning_of_month
    @valuation = InventoryValuation.new(as_of: @as_of, location_id: params[:location_id], group_name: params[:group])
    @start_date = InventoryRevaluation.start_date
    load_filter_options
  end

  # One-time: values the stock on hand at each product's basis and starts costed tracking (and sales) on
  # the chosen day (today, or back-dated when the stock was loaded from PDI's report for the day before).
  def opening
    as_of = [parse_date(params[:as_of]) || Date.current, Date.current].min
    InventoryRevaluation.opening!(user: current_user, as_of: as_of)
    redirect_to inventory_valuation_path, notice: t('.done', date: as_of.strftime('%b %-d, %Y'))
  rescue ArgumentError => e
    redirect_to inventory_valuation_path, alert: e.message
  end

  # Staging: back to before opening balances (InventoryReset).
  def reset_tracking
    removed = InventoryReset.reset!
    redirect_to inventory_valuation_path,
                notice: "Inventory reset: #{removed[:movements]} costed movement(s) deleted " \
                        "(#{removed[:adjustments]} manual adjustment(s)), stock zeroed at #{removed[:locations]} " \
                        "location row(s). Import PDI's on-hand next."
  end

  # Posts receipts, production and shipped orders from a past period (InventoryReplay).
  def replay
    replay = InventoryReplay.new(from: replay_from, to: parse_date(params[:to]) || Date.current).run!
    redirect_to inventory_valuation_path(as_of: replay.to, from: replay.from), notice: replay.summary
  rescue ArgumentError => e
    redirect_to inventory_valuation_path, alert: e.message
  end

  private

  def replay_from
    parse_date(params[:from]) || InventoryRevaluation.start_date || Date.current
  end

  def require_reset_allowed!
    redirect_to inventory_valuation_path, alert: t('.staging_only') unless InventoryReset.allowed?
  end

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
