class CustomerOrdersController < ApplicationController
  include RemembersListFilters

  permission_area :sales, lookups: %i[search]

  def dashboard
    today = Date.today

    @stats = {
      new: CustomerOrder.where(order_status: CustomerOrder::ACTIVE_STATUSES).count,
      due_this_week: CustomerOrder.where(order_status: CustomerOrder::ACTIVE_STATUSES)
                                  .where(required_delivery_date: today..today + 7).count,
      overdue: CustomerOrder.where(order_status: CustomerOrder::ACTIVE_STATUSES)
                            .where('required_delivery_date < ?', today).count,
      complete_this_month: CustomerOrder.where(order_status: 'Billed')
                                        .where('created_at >= ?', today.beginning_of_month).count,
      needs_billing: CustomerOrder.where(order_status: ['Shipped', 'Released for Billing', 'Delivered']).count
    }

    @upcoming = CustomerOrder
                .where(order_status: CustomerOrder::ACTIVE_STATUSES)
                .where('required_delivery_date >= ?', today)
                .order(required_delivery_date: :asc)
                .includes(:customer, :location)
                .limit(20)

    @orders_needing_production = production_shortfalls

    @last_import = SyncLog.for_process('Customer Order Import').first
  end

  def index
    return if redirected_old_list_link? || restore_list_filters('customer_orders', CustomerOrderListQuery::KEYS)

    @query = CustomerOrderListQuery.new(params, show_prices: helpers.sees?(:customer_pricing))
    @customer_orders = @query.relation
                             .includes(:customer, :location, :ship_from_location, :dispatches,
                                       customer_order_products: %i[product location])
                             .paginate(page: params[:page], per_page: @query.per_page)
    load_list_filter_options
  end

  def show
    @customer_order = CustomerOrder.find(params[:id])
    @locations = Location.where(location_category_id: 2)
    @freight_origins = Location.where(location_category_id: 1).or(Location.where(show_in_warehouse_dropdown: true))
                               .order(:company_name)
    @carriers = Vendor.order(:name)
  end

  def new
    # ?from_quote=ID pre-fills the order from an accepted quote at its locked prices.
    quote = Quote.accepted.find_by(id: params[:from_quote]) if params[:from_quote].present?
    quote = nil unless quote&.orderable?
    @customer_order = quote ? quote.build_order : CustomerOrder.new
    @customer_order.ship_from_location ||= current_warehouse
  end

  def edit
    @customer_order = CustomerOrder.find(params[:id])
  end

  def create_dispatch
    @customer_order = CustomerOrder.find(params[:id])

    # Assign a user and create a dispatch for the order here.
    # Adjust based on your app's logic; e.g., you might create a new Dispatch record.

    if @customer_order.assign_user_and_create_dispatch
      redirect_to @customer_order, notice: 'User assigned and dispatch created successfully.'
    else
      redirect_to @customer_order, alert: 'There was an error creating the dispatch.'
    end
  end

  def create
    @customer_order = CustomerOrder.new(customer_order_params)
    @customer_order.check_stock = true

    # A missing location is caught by the model's belongs_to validation below;
    # re-render (not redirect) so the user keeps what they entered.
    if @customer_order.location&.disabled?
      @customer_order.errors.add(:location, 'is currently disabled and cannot be used')
      respond_to do |format|
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @customer_order.errors, status: :unprocessable_content }
      end
      return
    end

    respond_to do |format|
      if @customer_order.save
        format.html { redirect_to customer_order_url(@customer_order), notice: 'Order was successfully created.' }
        format.json { render :show, status: :created, location: @customer_order }
      else
        format.html { render :new, status: :unprocessable_content }
        format.json { render json: @customer_order.errors, status: :unprocessable_content }
      end
    end
  end

  def update
    @customer_order = CustomerOrder.find(params[:id])

    @customer_order.check_stock = true
    respond_to do |format|
      if @customer_order.update(customer_order_params)
        format.html { redirect_to @customer_order, notice: 'Customer Order was successfully updated.' }
        format.json { render :show, status: :ok, location: @customer_order }
      else
        format.html { render :edit, status: :unprocessable_content }
        format.json { render json: @customer_order.errors, status: :unprocessable_content }
      end
    end
  end

  # Send to PDI: the order goes to PDI as a fuel order (PdiOrders::FuelOrderPush), once.
  def send_to_pdi
    order = CustomerOrder.find(params[:id])
    PdiOrders::FuelOrderPush.new(order).push!(user: current_user)
    redirect_to order, notice: pdi_push_notice(order)
  rescue ArgumentError, PdiOrders::OrderNumbers::RangeFull, *PdiWebService::FAILURES => e
    redirect_to order, alert: t('.failed', error: e.message)
  end

  # A push PDI queued: ask PDI for its answer.
  def check_pdi
    order = CustomerOrder.find(params[:id])
    PdiOrders::FuelOrderPush.new(order).check!
    redirect_to order, notice: pdi_push_notice(order)
  rescue *PdiWebService::FAILURES => e
    redirect_to order, alert: t('.failed', error: e.message)
  end

  def bulk_close
    ids = Array(params[:order_ids]).map(&:to_i).select(&:positive?)
    return redirect_to dashboard_production_orders_path, alert: 'No orders selected.' if ids.empty?

    count = CustomerOrder.where(id: ids).update_all(order_status: 'Delivered')
    redirect_to dashboard_production_orders_path(tab: params[:tab].presence || 'buy'),
                notice: "#{count} order(s) marked as Delivered."
  end

  def destroy
    @customer_order = CustomerOrder.find(params[:id])
    if @customer_order.destroy
      redirect_to dispatches_path, notice: t('.deleted')
    else
      redirect_to @customer_order, alert: @customer_order.errors.full_messages.to_sentence
    end
  end

  private

  # Older links (dashboard tiles, the dispatch page) use status_preset / order_statuses / order_status / sort_by:
  # send them to the same list in today's params. True when it redirected.
  def redirected_old_list_link?
    legacy = request.query_parameters.slice('status_preset', 'order_statuses', 'order_status', 'sort_by')
    return false if legacy.empty?

    preset = legacy['status_preset'] == 'active' ? 'open' : legacy['status_preset'].presence
    quick = preset || { 'unassigned' => 'unassigned', 'On Hold' => 'on_hold' }[legacy['order_status']]
    sort = { 'required_delivery_date' => 'delivery_asc', 'oldest' => 'order_date_asc' }[legacy['sort_by']]
    redirect_to customer_orders_path(request.query_parameters.except(*legacy.keys)
                                            .merge('quick' => quick, 'statuses' => legacy['order_statuses'],
                                                   'sort' => sort, 'filtered' => '1').compact_blank)
    true
  end

  def load_list_filter_options
    @customers = Customer.where(id: CustomerOrder.select(:customer_id)).order(:name)
    @ship_tos = Location.where(id: CustomerOrder.select(:location_id)).order(:company_name)
    @warehouses = Location.where(show_in_warehouse_dropdown: true).order(:company_name)
    @products = Product.where(id: CustomerOrderProduct.select(:product_id)).order(:name)
    @categories = Product.where.not(category: [nil, '']).distinct.order(:category).pluck(:category)
    @salespeople = CustomerOrder.where.not(salesperson: [nil, '']).distinct.order(:salesperson).pluck(:salesperson)
    @carriers = CustomerOrder.where.not(carrier: [nil, '']).distinct.order(:carrier).pluck(:carrier)
  end

  def production_shortfalls
    cops = CustomerOrderProduct
           .joins(:customer_order)
           .where(item_type: 'production')
           .where.not(product_id: nil)
           .where(customer_orders: { order_status: CustomerOrder::ACTIVE_STATUSES })
           .includes(:product, customer_order: %i[customer location])

    result = {}
    cops.each do |cop|
      next unless cop.product

      needed    = (cop.quantity || 0).to_f
      in_stock  = cop.product.current_stock.to_f
      shortfall = needed - in_stock
      next unless shortfall > 0

      order = cop.customer_order
      next if ['Cancelled as Order', 'Cancelled as Quote'].include?(order.order_status)

      result[order.id] ||= { order: order, shortfalls: [] }
      result[order.id][:shortfalls] << {
        product: cop.product,
        needed: needed,
        in_stock: in_stock,
        shortfall: shortfall
      }
    end

    result.values.sort_by { |r| r[:order].required_delivery_date || Date.new(9999) }
  end

  def customer_order_params
    params.require(:customer_order).permit(:required_delivery_date, :product, :freight_only, :customer_id,
                                           :location_id, :ship_from_location_id, :approximate_product_amount, :notes, :order_status, :freight_terms,
                                           :customer_po_number, :release_number, :delivery_time, customer_order_products_attributes: %i[id product_id quantity price quote_product_id pricing_rule_id _destroy], thing_ids: [])
  end

  def pdi_push_notice(order)
    if order.external_order_no.present?
      t('customer_orders.send_to_pdi.sent', number: order.external_order_no)
    else
      t('customer_orders.send_to_pdi.queued')
    end
  end
end
