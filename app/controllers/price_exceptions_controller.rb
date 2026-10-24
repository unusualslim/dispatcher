# Imported (PDI) order lines whose price differs from the customer's locked
# quote price or pricing rule price, on orders that haven't been billed yet.
class PriceExceptionsController < ApplicationController
  permission_area :sales

  FILTERS = {
    'lock' => %w[lock_mismatch],
    'rule' => %w[rule_mismatch],
    'all' => CustomerOrderProduct::PRICE_MISMATCHES
  }.freeze

  def index
    @filter = FILTERS.key?(params[:filter]) ? params[:filter] : 'lock'
    base = CustomerOrderProduct.joins(:customer_order)
                               .where(customer_orders: { order_status: PriceCheckService::OPEN_STATUSES })
    @counts = base.where(price_check: CustomerOrderProduct::PRICE_MISMATCHES).group(:price_check).count
    @lines  = base.where(price_check: FILTERS[@filter])
                  .includes(:product, :pricing_rule, quote_product: :quote, customer_order: :customer)
                  .order('customer_orders.required_delivery_date ASC NULLS LAST, customer_orders.id')
                  .paginate(page: params[:page], per_page: 50)
    @last_checked = CustomerOrderProduct.maximum(:price_checked_at)
  end

  def recheck
    count = PriceCheckService.recheck_open_orders!
    redirect_to price_exceptions_path(filter: params[:filter]),
                notice: "Re-checked prices on #{count} open imported order(s)."
  end
end
