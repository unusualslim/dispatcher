# Production → Suggested Production (SuggestedProduction): MRP's planned production runs with start dates and the
# orders behind them. A planner ticks runs and creates production orders; nothing is created on its own.
class SuggestedProductionsController < ApplicationController
  include TickedRows

  permission_area :production

  def index
    @runs = SuggestedProduction.new.runs
    @runs = @runs.select { |r| r.location&.id == current_warehouse.id } if current_warehouse
  end

  def create
    orders = SuggestedProduction.create_orders!(ticked(:runs, %i[product_id location_id quantity start_on need_date]))
    return redirect_to(suggested_productions_path, alert: t('.nothing')) if orders.empty?

    redirect_to kanban_production_orders_path,
                notice: t('.created', count: orders.size, numbers: orders.map(&:number).join(', '))
  end
end
