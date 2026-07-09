class WarehouseController < ApplicationController
  before_action :require_admin!

  def kanban
    yesterday = Date.today - 1
    tomorrow  = Date.today + 1

    @dispatches = Dispatch
      .includes(:driver, :truck, customer_orders: [:customer, :location, { customer_order_products: :product }])
      .where.not(status: :deleted)
      .where(dispatch_date: yesterday..tomorrow)
      .order(:dispatch_date, :position)
      .group_by(&:dispatch_date)

    @today     = Date.today
    @yesterday = yesterday
    @tomorrow  = tomorrow
  end
end
