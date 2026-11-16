# Dispatch → Tank Feeds: each feed's status (last file, readings, schedule) and its tanks, with the new ones
# waiting to be set up: pick its location (the tank comes from the monitor's profile, TankSetup), link it to an
# existing tank, or ignore it. Export lists the linked monitor tanks with the IDs to key back into Kii and Smartank.
class FeedTanksController < ApplicationController
  permission_area :dispatch
  before_action :set_feed_tank, only: %i[update setup]

  PROCESSES = {
    'kii' => TankKiiSyncJob::PROCESS_NAME, 'smartank' => TankSmartankSyncJob::PROCESS_NAME,
    'plant_0002' => TankPlant0002SyncJob::PROCESS_NAME
  }.freeze
  SHOWS = { 'setup' => 'Needs setup', 'linked' => 'Linked', 'ignored' => 'Ignored', 'all' => 'All' }.freeze

  def index
    @show = params[:show].presence_in(SHOWS.keys) || 'setup'
    @feed = params[:feed].presence_in(FeedTank::FEEDS.keys)
    @feed_tanks = shown(FeedTank.includes(tank: :location)).order(:feed, :name)
    @status = TankFeedStatus.new.feeds
    @tanks = tank_choices
  end

  def update
    @feed_tank.update!(feed_tank_params)
    redirect_back_or_to feed_tanks_path, notice: t('.updated', name: @feed_tank.label)
  end

  # The location selector: the monitor's tank becomes an app tank at the chosen location.
  def setup
    location = Location.find_by(id: params[:location_id])
    problem = setup_problem(location, setup_product_id)
    return redirect_back_or_to(feed_tanks_path, alert: problem) if problem

    tank = TankSetup.new(@feed_tank).apply!(location: location, product_id: setup_product_id)
    redirect_back_or_to feed_tanks_path, notice: t('.linked', name: @feed_tank.label, tank: tank.label)
  end

  def export
    send_data TankFeedExport.new.to_csv, type: 'text/csv',
                                         filename: "tank-monitor-ids-#{Time.zone.today.strftime('%Y%m%d')}.csv"
  end

  private

  def setup_product_id
    params[:product_id].to_s.strip.presence
  end

  def setup_problem(location, product_id)
    return t('feed_tanks.setup.no_location') unless location

    t('feed_tanks.setup.no_product', id: product_id) if product_id && !Product.exists?(id: product_id)
  end

  def tank_choices
    Tank.active.ordered.includes(:location).map { |tank| [tank.label, tank.id] }
  end

  def set_feed_tank
    @feed_tank = FeedTank.find(params[:id])
  end

  def shown(scope)
    scope = scope.in_feed(@feed) if @feed
    case @show
    when 'setup' then scope.needs_setup
    when 'linked' then scope.where.not(tank_id: nil)
    when 'ignored' then scope.where(ignored: true)
    else scope
    end
  end

  def feed_tank_params
    params.require(:feed_tank).permit(:tank_id, :ignored)
  end
end
