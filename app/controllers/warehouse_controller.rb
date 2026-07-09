class WarehouseController < ApplicationController
  before_action :require_admin!

  def kanban
    yesterday = Date.today - 1
    tomorrow  = Date.today + 1

    @terminals = Location.where(id: [3, 408]).order(:company_name)

    # Filter by terminal if selected
    if params[:location_id].present?
      @selected_terminal = @terminals.find_by(id: params[:location_id])
      origin_string = @selected_terminal&.full_address_with_company
      dispatches_scope = Dispatch.where(origin: origin_string)
    else
      @selected_terminal = nil
      dispatches_scope = Dispatch.all
    end

    @dispatches = dispatches_scope
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
