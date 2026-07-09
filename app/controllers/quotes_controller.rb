class QuotesController < ApplicationController
  before_action :require_admin!
  before_action :set_quote, only: [:show, :edit, :update, :destroy, :send_quote, :accept, :reject]

  def index
    @quotes = Quote.includes(:customer, :location)
                   .order(created_at: :desc)
                   .paginate(page: params[:page], per_page: 25)
  end

  def show
  end

  def new
    @quote = Quote.new
    @quote.quote_products.build
  end

  def create
    @quote = Quote.new(quote_params)
    if @quote.save
      redirect_to @quote, notice: "Quote #{@quote.quote_number} created."
    else
      render :new
    end
  end

  def edit
  end

  def update
    if @quote.update(quote_params)
      redirect_to @quote, notice: "Quote updated."
    else
      render :edit
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
    order = CustomerOrder.create!(
      customer:               @quote.customer,
      location:               @quote.location,
      order_status:           :New,
      order_date:             Date.today,
      required_delivery_date: @quote.expiry_date,
      notes:                  "Created from Quote #{@quote.quote_number}"
    )
    @quote.quote_products.each do |qp|
      order.customer_order_products.create!(
        product_id:   qp.product_id,
        product_name: qp.product_name,
        quantity:     qp.quantity,
        price:        qp.price
      )
    end
    order.sync_approximate_amount if order.respond_to?(:sync_approximate_amount)
    @quote.update!(status: 'accepted', customer_order: order)
    redirect_to order, notice: "Quote accepted — order created."
  end

  def reject
    @quote.update!(status: 'rejected')
    redirect_to @quote, notice: "Quote marked as rejected."
  end

  private

  def set_quote
    @quote = Quote.includes(:customer, :location, quote_products: :product).find(params[:id])
  end

  def quote_params
    params.require(:quote).permit(
      :customer_id, :location_id, :expiry_date, :notes,
      quote_products_attributes: [:id, :product_id, :product_name, :quantity, :price, :_destroy]
    )
  end
end
