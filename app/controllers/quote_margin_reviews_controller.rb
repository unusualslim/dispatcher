# Every active/scheduled locked quote line, comparing the fixed quoted price
# with today's cost and rule price. Internal only — shows costs and margins.
class QuoteMarginReviewsController < ApplicationController
  before_action :require_admin!

  STATUSES = %w[reprice watch ok unknown].freeze

  def index
    all = QuoteMarginReview.open_locks(customer_id: params[:customer_id])
    @counts = all.group_by(&:status).transform_values(&:size)
    @filter = STATUSES.include?(params[:status]) ? params[:status] : nil
    @lines  = @filter ? all.select { |l| l.status.to_s == @filter } : all
    @customer = Customer.find_by(id: params[:customer_id]) if params[:customer_id].present?
  end
end
