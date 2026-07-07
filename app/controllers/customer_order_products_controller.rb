class CustomerOrderProductsController < ApplicationController
  before_action :require_admin!
  before_action :set_customer_order, except: [:unlinked, :link_codes]

  def create
    @customer_order_product = @customer_order.customer_order_products.new(customer_order_product_params)

    if @customer_order_product.save
      redirect_to @customer_order, notice: 'Product was successfully added.'
    else
      flash[:alert] = 'There was an error adding the product.'
      redirect_to @customer_order
    end
  end

  def update
    @customer_order_product = CustomerOrderProduct.find(params[:id])
    if @customer_order_product.update(customer_order_product_params)
      redirect_to customer_order_path(@customer_order_product.customer_order), notice: 'Product updated successfully.'
    else
      render :edit
    end
  end

  def destroy
    @customer_order_product = CustomerOrderProduct.find(params[:id])
    @customer_order_product.destroy
    redirect_to @customer_order, notice: 'Product removed from order successfully.'
  end

  # GET /product_code_links
  # Shows unique unmatched ODOR product codes across all imported orders
  def unlinked
    rows = CustomerOrderProduct
      .where(product_id: nil)
      .where.not(product_name: nil)
      .pluck(:product_name)
      .map { |n| n.split(' / ').first.strip }
      .tally
      .sort_by { |code, _count| code }

    @unlinked = rows.map do |code, count|
      { code: code, count: count }
    end

    @products = Product.order(:name)
    @total_lines = @unlinked.sum { |r| r[:count] }
  end

  # POST /product_code_links/update
  def link_codes
    linked = 0
    params[:mappings]&.each do |code, product_id|
      next if product_id.blank?
      updated = CustomerOrderProduct
        .where(product_id: nil)
        .where("product_name LIKE ?", "#{ActiveRecord::Base.sanitize_sql_like(code)} /%")
        .update_all(product_id: product_id)
      updated += CustomerOrderProduct
        .where(product_id: nil)
        .where(product_name: code)
        .update_all(product_id: product_id)
      linked += updated
    end
    redirect_to product_code_links_path, notice: "#{linked} order line(s) linked."
  end

  private

  def set_customer_order
    @customer_order = CustomerOrder.find(params[:customer_order_id])
  end

  def customer_order_product_params
    params.require(:customer_order_product).permit(:product_id, :quantity, :price, :item_type)
  end
end
