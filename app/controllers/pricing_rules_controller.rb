class PricingRulesController < ApplicationController
  permission_area :sales, lookups: %i[lookup]
  before_action :set_rule, only: %i[show edit update destroy]

  def index
    @rules = PricingRule.includes(
      :customer,
      products: [:standard_cost_histories, { product_components: { component_product: :standard_cost_histories } }]
    ).order(:name)
  end

  def new
    @rule = PricingRule.new
    load_form_data
  end

  def create
    @rule = PricingRule.new(rule_params)
    if @rule.save
      sync_products
      redirect_to pricing_rules_path, notice: "Pricing rule \"#{@rule.name}\" created."
    else
      load_form_data
      render :new, status: :unprocessable_content
    end
  end

  def edit
    load_form_data
  end

  def update
    if @rule.update(rule_params)
      sync_products
      redirect_to edit_pricing_rule_path(@rule), notice: "Pricing rule \"#{@rule.name}\" updated."
    else
      load_form_data
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @rule.destroy
    redirect_to pricing_rules_path, notice: 'Pricing rule deleted.'
  end

  # GET /pricing_rules/lookup?customer_id=X&product_id=Y
  # Returns the calculated price for use in the order form.
  #   rule_id=Z  price from that specific rule instead of the best match
  #   live=1     ignore locked quote prices (used when building a new quote)
  def lookup
    product  = Product.find_by(id: params[:product_id])
    customer = Customer.find_by(id: params[:customer_id])

    result =
      if params[:rule_id].present?
        specific_rule_result(PricingRule.find_by(id: params[:rule_id]), product)
      else
        PricingRuleService.lookup(customer, product, include_locks: params[:live].blank?)
      end

    return render(json: { price: nil }) unless result

    json = {
      price: result[:price]&.to_f&.round(4),
      missing_components: result[:missing_components].map do |c|
        { id: c.id, name: c.name, url: product_path(c) }
      end
    }

    if (qp = result[:quote_product])
      json.merge!(
        source: 'quote',
        quote_product_id: qp.id,
        quote_number: qp.quote.quote_number,
        quote_url: quote_path(qp.quote),
        locked_through: qp.locked_through&.strftime('%b %-d, %Y')
      )
    else
      rule = result[:rule]
      json.merge!(
        source: 'rule',
        rule_id: rule.id,
        rule_name: rule.name,
        method: rule.pricing_method,
        basis: rule.pricing_basis_label
      )
    end

    render json: json
  end

  private

  def specific_rule_result(rule, product)
    return nil unless rule && product

    price   = rule.calculated_price(product)
    missing = rule.pricing_basis == 'standard_calculated' && price.nil? ? product.bom_components_missing_standard_cost : []
    return nil if price.nil? && missing.empty?

    { price: price, rule: rule, quote_product: nil, missing_components: missing }
  end

  def set_rule
    @rule = PricingRule.find(params[:id])
  end

  def load_form_data
    @customers = Customer.selectable(@rule&.customer_id).order(:name)
    @products  = Product.selectable(@rule&.pricing_rule_products&.map(&:product_id)).includes(:standard_cost_histories,
                                                                                              product_components: { component_product: :standard_cost_histories })
                        .order(:name)
  end

  def rule_params
    params.require(:pricing_rule).permit(
      :name, :customer_id, :pricing_basis, :pricing_method,
      :value, :effective_date, :expiration_date
    )
  end

  def sync_products
    product_ids = Array(params[:pricing_rule][:product_ids]).reject(&:blank?)
    @rule.pricing_rule_products.destroy_all
    product_ids.each { |pid| @rule.pricing_rule_products.create!(product_id: pid) }
  end
end
