# Sales → Freight Rules: which freight table to use, and what its rate means, for each side, charge type, origin,
# class, carrier and customer. Freight tables are listed on the Tables tab; classes have their own page.
class FreightRulesController < ApplicationController
  permission_area :sales
  before_action :set_rule, only: %i[edit update destroy]
  before_action :load_options, only: %i[new create edit update]

  def index
    @tab = %w[tables lanes].include?(params[:tab]) ? params[:tab] : 'rules'
    load_lanes if @tab == 'lanes'
    load_rules
    @tables = FreightTable.ordered.includes(:rates)
    @rule_counts = FreightRule.group(:freight_table_id).count
  end

  def new
    @rule = FreightRule.new(effective_from: Date.current, side: params[:side].presence || 'sale',
                            charge_type: params[:charge_type].presence || 'freight')
    @rule.basis = FreightRule::DEFAULT_BASIS[@rule.charge_type]
  end

  def edit; end

  def create
    @rule = FreightRule.new(rule_params)
    if @rule.save
      redirect_to freight_rules_path, notice: t('.created', name: @rule.name)
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    if @rule.update(rule_params)
      redirect_to freight_rules_path, notice: t('.updated', name: @rule.name)
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @rule.destroy!
    redirect_to freight_rules_path, notice: t('.deleted', name: @rule.name)
  end

  private

  def set_rule
    @rule = FreightRule.find(params[:id])
  end

  def load_rules
    @rules = FreightRule.includes(:freight_table, :origin_location, :freight_class, :carrier, :customer).ordered
    @rules = @rules.active if params[:show_inactive].blank?
  end

  def load_lanes
    @lanes = FreightLane.includes(:origin_location, :destination_location)
                        .joins(:destination_location).order('locations.company_name')
    @lanes = @lanes.where(origin_location_id: params[:origin_id]) if params[:origin_id].present?
    @lanes = @lanes.paginate(page: params[:page], per_page: 100)
    load_lane_pickers
  end

  def load_lane_pickers
    @lane_origins = Location.where(id: FreightLane.select(:origin_location_id)).order(:company_name)
    @lane_origin_choices = Location.where(location_category_id: 1).or(Location.where(show_in_warehouse_dropdown: true))
                                   .order(:company_name)
    @lane_destination_choices = Location.order(:company_name).select(:id, :company_name, :city)
  end

  def load_options
    @tables = FreightTable.ordered
    @classes = FreightClass.ordered
    @origins = Location.where(location_category_id: 1).or(Location.where(show_in_warehouse_dropdown: true))
                       .order(:company_name)
    @carriers = Vendor.order(:name)
    @customers = Customer.order(:name)
  end

  def rule_params
    params.require(:freight_rule).permit(:name, :side, :charge_type, :basis, :freight_table_id, :origin_location_id,
                                         :freight_class_id, :carrier_id, :customer_id, :markup_percent,
                                         :minimum_amount, :calculation, :bill_full_load, :effective_from,
                                         :effective_to, :active, :notes)
  end
end
