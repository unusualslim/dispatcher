class CalendarController < ApplicationController
  def index
  end

  def events
    customer_orders = CustomerOrder.all.map do |order|
      {
        title: "Order ##{order.id}",
        start: order.required_delivery_date,
        url: customer_order_path(order)
      }
    end

    dispatches = Dispatch.all.map do |dispatch|
      {
        title: "Dispatch ##{dispatch.id}",
        start: dispatch.dispatch_date,
        url: dispatch_path(dispatch)
      }
    end

    render json: customer_orders + dispatches
  end
end