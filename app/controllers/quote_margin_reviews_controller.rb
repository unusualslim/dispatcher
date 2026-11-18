# Every active/scheduled locked quote line, comparing the fixed quoted price
# with today's cost and rule price. Internal only — shows costs and margins.
class QuoteMarginReviewsController < ApplicationController
  permission_area :sales, feature: :quotes, flag: :costs

  STATUSES = %w[reprice increase watch ok unknown].freeze

  def index
    all = QuoteMarginReview.open_locks(customer_id: params[:customer_id])
    @counts = all.group_by(&:status).transform_values(&:size)
    @filter = STATUSES.include?(params[:status]) ? params[:status] : nil
    @lines  = @filter ? all.select { |l| l.status.to_s == @filter } : all
    @customer = Customer.find_by(id: params[:customer_id]) if params[:customer_id].present?
  end

  # The selected quotes are re-quoted at today's rule prices from the chosen date, accepted (their old lines end the
  # day before) and, if asked, emailed to the customer.
  def accept_increases
    quotes = Quote.accepted_locks.where(id: Array(params[:quote_ids])).includes(:customer, quote_products: :product)
    return redirect_back_or_to(quote_margin_review_path, alert: t('.none')) if quotes.empty?

    effective = Date.iso8601(params[:effective_on].to_s) rescue Date.current # rubocop:disable Style/RescueModifier
    emailed = quotes.count do |quote|
      QuoteIncrease.new(quote, effective, current_user).run!(email: params[:email] == '1')
    end
    redirect_to quote_margin_review_path(status: 'increase'), notice: done_notice(quotes.size, effective, emailed)
  end

  private

  def done_notice(count, effective, emailed)
    t('.done', count: count, date: effective.strftime('%m/%d/%Y'),
               emailed: emailed.positive? ? t('.emailed', count: emailed) : '')
  end
end
