# Dispatch → Tank Feeds: each feed's status (last file, readings, schedule) and its tanks, with the new ones
# waiting to be set up: create an app tank from one, link it to an existing tank, or ignore it.
class FeedTanksController < ApplicationController
  permission_area :dispatch
  before_action :set_feed_tank, only: :update

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

  private

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
