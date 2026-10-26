# Admin → Merge Customers: folds app customers the PDI Master Data import couldn't match by name into
# their PDI-linked twins (CustomerMerge), with a preview before anything moves.
class CustomerMergesController < ApplicationController
  before_action :require_admin!

  # App customers without a PDI ID, most orders first, with suggested PDI matches.
  def index
    order_counts = CustomerOrder.where.not(customer_id: nil).group(:customer_id).count
    suggestions = CustomerMerge::Suggestions.new
    @rows = Customer.where(pdi_customer_id: nil).order(:name).map do |customer|
      { customer: customer, orders: order_counts[customer.id].to_i, matches: suggestions.for(customer) }
    end
    @rows.sort_by! { |row| -row[:orders] }
  end

  # Pick the target (source_id fixed); with target_id, preview the merge.
  def new
    @source = Customer.find(params[:source_id])
    @target = Customer.find_by(id: params[:target_id])
    @merge = CustomerMerge.new(@source, @target) if @target
  rescue ArgumentError => e
    redirect_to customer_merges_path, alert: e.message
  end

  def create
    merge = CustomerMerge.new(Customer.find(params[:source_id]), Customer.find(params[:target_id]))
    notice = merged_notice(merge) # counted before the records move
    merge.merge!
    redirect_to customer_merges_path, notice: notice
  rescue ArgumentError, ActiveRecord::ActiveRecordError => e
    log_failure(e)
    redirect_to customer_merges_path, alert: t('.failed', error: e.message)
  end

  # Customer search for the target picker (PDI-linked customers show their PDI ID).
  def targets
    term = params[:q].to_s.strip
    customers = Customer.order(:name).limit(25)
    if term.present?
      customers = customers.where('name ILIKE :q OR pdi_customer_id = :exact', q: "%#{term}%", exact: term)
    end
    render json: customers.map { |c| { id: c.id, text: label(c) } }
  end

  private

  def log_failure(error)
    Rails.logger.warn "[CustomerMerge] #{params[:source_id]} → #{params[:target_id]} failed: " \
                      "#{error.class}: #{error.message}"
  end

  def merged_notice(merge)
    t('customer_merges.create.merged', source: merge.source.name, target: merge.target.name,
                                       summary: merge.summary.presence || t('customer_merges.create.nothing_moved'))
  end

  def label(customer)
    customer.pdi_customer_id ? "#{customer.name} [PDI #{customer.pdi_customer_id}]" : customer.name
  end
end
