class QuotesController < ApplicationController
  before_action :require_admin!
  before_action :set_quote, only: [:show, :edit, :update, :destroy, :send_quote, :accept, :reject, :end_lock, :margin_review, :requote]
  before_action :require_editable, only: [:edit, :update]

  def index
    @quotes = Quote.includes(:customer, :location, :quote_products)
                   .order(created_at: :desc)
    @quotes = @quotes.where(customer_id: params[:customer_id]) if params[:customer_id].present?
    @quotes = @quotes.paginate(page: params[:page], per_page: 25)
  end

  def show
  end

  def new
    @quote = Quote.new(
      customer_id:   params[:customer_id],
      locks_pricing: true,
      valid_from:    Date.today,
      expiry_date:   Date.today.end_of_month
    )
    @quote.quote_products.build
    load_form_data
  end

  def create
    @quote = Quote.new(quote_params)
    if @quote.save
      redirect_to @quote, notice: "Quote #{@quote.quote_number} created."
    else
      load_form_data
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_data
  end

  def update
    if @quote.update(quote_params)
      redirect_to @quote, notice: "Quote updated."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @quote.destroy
    redirect_to quotes_path, notice: "Quote deleted."
  end

  def send_quote
    if @quote.customer.email.blank?
      return redirect_to @quote, alert: "Customer has no email address on file."
    end
    QuoteMailer.send_quote(@quote).deliver_now
    @quote.update!(status: 'sent', sent_at: Time.current)
    redirect_to @quote, notice: "Quote #{@quote.quote_number} sent to #{@quote.customer.email}."
  end

  def accept
    return redirect_to(@quote, alert: "This quote has already been #{@quote.status}.") unless @quote.editable?
    begin
      @quote.accept!(current_user)
    rescue ActiveRecord::RecordInvalid => e
      return redirect_to @quote, alert: "Couldn't accept: #{e.record.errors.full_messages.to_sentence}"
    end
    notice = if @quote.locks_pricing?
               "Quote accepted — prices locked #{@quote.valid_from.strftime('%b %-d')} through #{@quote.expiry_date.strftime('%b %-d, %Y')}."
             else
               "Quote accepted."
             end
    redirect_to @quote, notice: notice
  end

  # End an accepted quote's price lock early (today or a later date).
  def end_lock
    unless @quote.lock_endable?
      return redirect_to @quote, alert: "This quote's prices aren't currently locked."
    end

    on = Date.parse(params[:lock_ended_on].to_s) rescue nil
    @quote.end_lock!(current_user, on: on, reason: params[:lock_end_reason])
    msg = on == Date.today ? "Price lock ended. Orders for #{@quote.customer.name} now use the live pricing rules." :
                             "Price lock will end #{on.strftime('%b %-d, %Y')}; orders from that day use the live pricing rules."
    redirect_to @quote, notice: msg
  rescue ActiveRecord::RecordInvalid => e
    redirect_to @quote, alert: "Couldn't end the lock: #{e.record.errors.full_messages.to_sentence}"
  end

  # Internal justification: locked prices vs today's costs, with the cost
  # changes behind any margin erosion. Shows costs — never send to customers.
  def margin_review
    @lines = QuoteMarginReview.for_quote(@quote)
  end

  def requote
    new_quote = @quote.create_requote!(QuoteMarginReview.for_quote(@quote))
    redirect_to edit_quote_path(new_quote),
                notice: "Draft #{new_quote.quote_number} created at today's prices. Review, send, and accept it to replace #{@quote.quote_number}."
  end

  def reject
    @quote.update!(status: 'rejected')
    redirect_to @quote, notice: "Quote marked as rejected."
  end

  private

  def set_quote
    @quote = Quote.includes(:customer, :location, quote_products: [:product, :pricing_rule]).find(params[:id])
  end

  def require_editable
    redirect_to @quote, alert: "Accepted or rejected quotes can't be edited." unless @quote.editable?
  end

  def load_form_data
    # Finished goods plus anything sold under a pricing rule.
    @products = Product.finished_goods
                       .or(Product.where(id: PricingRuleProduct.select(:product_id)))
                       .order(:name)
    # Rules and the products in each, for "add products from rule" on the form.
    @pricing_rules = PricingRule.includes(:customer, :pricing_rule_products).order(:name)
  end

  def quote_params
    params.require(:quote).permit(
      :customer_id, :location_id, :valid_from, :expiry_date, :notes, :locks_pricing,
      quote_products_attributes: [:id, :product_id, :quantity, :price, :pricing_rule_id, :_destroy]
    )
  end
end
