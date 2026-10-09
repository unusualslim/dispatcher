class PricingRulesController < ApplicationController
  before_action :require_admin!
  before_action :set_rule, only: [:show, :edit, :update, :destroy]

  def index
    @rules = PricingRule.includes(:customer, :products).order(:name)
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
      render :new, status: :unprocessable_entity
    end
  end

  def edit
    load_form_data
  end

  def update
    if @rule.update(rule_params)
      sync_products
      redirect_to pricing_rules_path, notice: "Pricing rule \"#{@rule.name}\" updated."
    else
      load_form_data
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy
    redirect_to pricing_rules_path, notice: "Pricing rule deleted."
  end

  # GET /pricing_rules/lookup?customer_id=X&product_id=Y
  # Returns the calculated price for use in the order form.
  def lookup
    product  = Product.find_by(id: params[:product_id])
    customer = Customer.find_by(id: params[:customer_id])

    result = PricingRuleService.lookup(customer, product)

    if result
      render json: {
        price:     result[:price].to_f.round(4),
        rule_name: result[:rule].name,
        method:    result[:rule].pricing_method,
        basis:     result[:rule].pricing_basis_label
      }
    else
      render json: { price: nil }
    end
  end

  private

  def set_rule
    @rule = PricingRule.find(params[:id])
  end

  def load_form_data
    @customers = Customer.order(:name)
    @products  = Product.order(:name)
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
