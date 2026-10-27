class FinancialDashboardsController < ApplicationController
  permission_area :accounting

  def show
    month = parse_month(params[:month]) || Date.current.beginning_of_month
    @dashboard = FinancialDashboard.new(month: month)
    @months = (0..23).map { |n| Date.current.beginning_of_month << n }
  end

  private

  def parse_month(value)
    Date.strptime(value, '%Y-%m') if value.present?
  rescue Date::Error
    nil
  end
end
