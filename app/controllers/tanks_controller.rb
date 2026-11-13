# Dispatch → Tanks: the tanks we watch, their setup, their feed tanks and readings, and manual readings for sites
# without a monitor (the dispatcher phones for a level).
class TanksController < ApplicationController
  permission_area :dispatch, lookups: %i[locations]
  before_action :set_tank, only: %i[show edit update destroy record_reading]

  def index
    @tanks = filtered(Tank.includes(:location, :product, :feed_tanks)).ordered
    @needs_setup = FeedTank.needs_setup.count
    @products = Product.where(id: Tank.select(:product_id)).order(:name)
  end

  def show
    @sources = @tank.feed_tanks.order(:feed, :name)
    @readings = TankReading.where(feed_tank_id: @sources.map(&:id)).includes(:feed_tank)
                           .order(read_at: :desc).limit(60)
  end

  def new
    @feed_tank = FeedTank.find_by(id: params[:feed_tank_id])
    @tank = Tank.new(prefill(@feed_tank))
  end

  def edit; end

  def create
    @tank = Tank.new(tank_params)
    @feed_tank = FeedTank.find_by(id: params[:feed_tank_id])
    if @tank.save
      @feed_tank&.update!(tank: @tank, ignored: false)
      redirect_to after_save_path, notice: t('.created', name: @tank.label)
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @tank.update(tank_params)
      redirect_to @tank, notice: t('.updated', name: @tank.label)
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @tank.destroy!
    redirect_to tanks_path, notice: t('.deleted', name: @tank.label)
  end

  # A level typed in by hand, at the time given (Eastern), default now.
  def record_reading
    gallons = BigDecimal(params[:gallons].to_s.delete(','), exception: false)
    return redirect_to(@tank, alert: t('.no_gallons')) unless gallons && gallons >= 0

    @tank.record_manual_reading!(gallons, read_at: manual_read_at, by: current_user)
    redirect_to @tank, notice: t('.recorded', gallons: gallons.to_i, at: helpers.reading_time(manual_read_at))
  end

  # Location picker for the tank form (any location: customer sites, warehouses, terminals).
  def locations
    term = "%#{Location.sanitize_sql_like(params[:q].to_s.strip)}%"
    scope = Location.where('company_name ILIKE :t OR city ILIKE :t OR pdi_site_code ILIKE :t', t: term)
    render json: { results: scope.order(:company_name).limit(25).map { |l| { id: l.id, text: l.picker_label } } }
  end

  private

  def manual_read_at
    @manual_read_at ||= Time.find_zone!(TankFeeds::Base::EASTERN).parse(params[:read_at].to_s) || Time.current
  end

  def set_tank
    @tank = Tank.find(params[:id])
  end

  def filtered(scope)
    scope = scope.active unless params[:inactive] == '1'
    scope = scope.where(ownership: params[:ownership]) if Tank::OWNERSHIPS.key?(params[:ownership])
    scope = scope.where(product_id: params[:product_id]) if params[:product_id].present?
    scope
  end

  # A new tank from a feed tank starts with the feed's name and capacity.
  def prefill(feed_tank)
    return {} unless feed_tank

    details = feed_tank.details
    capacity = details['capacity'].to_s.delete(',').to_d.nonzero?
    { name: feed_tank.name, capacity_gallons: capacity, ownership: 'managed' }
  end

  def after_save_path
    params[:return_to] == 'feeds' ? feed_tanks_path : @tank
  end

  def tank_params
    params.require(:tank).permit(:name, :location_id, :product_id, :ownership, :capacity_gallons, :fill_limit_gallons,
                                 :bottom_gallons, :active, :notes)
  end
end
