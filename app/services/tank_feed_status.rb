# Per feed: its tanks (linked / waiting for setup / ignored), the newest reading, readings in the last day,
# stale linked tanks, and the last file the pickup job or a manual import brought in.
class TankFeedStatus
  Feed = Struct.new(:key, :name, :linked, :needs_setup, :ignored, :newest_read_at, :readings_24h, :stale,
                    :last_log, :schedule, keyword_init: true)

  def feeds
    FeedTank::FEEDS.map { |key, name| feed(key, name) }
  end

  private

  def feed(key, name)
    Feed.new(key: key, name: name, **tank_counts(key), newest_read_at: newest[key], readings_24h: recent[key].to_i,
             stale: stale_counts[key].to_i, last_log: last_logs[key], schedule: schedules[key])
  end

  def tank_counts(key)
    { linked: 'linked', needs_setup: 'setup', ignored: 'ignored' }.transform_values do |state|
      counts[[key, state]].to_i
    end
  end

  def counts
    @counts ||= FeedTank.group(:feed).group(Arel.sql(state_sql)).count
  end

  def state_sql
    "CASE WHEN ignored THEN 'ignored' WHEN tank_id IS NULL THEN 'setup' ELSE 'linked' END"
  end

  def newest
    @newest ||= FeedTank.where(ignored: false).group(:feed).maximum(:last_read_at)
  end

  def recent
    @recent ||= TankReading.joins(:feed_tank).where(read_at: 24.hours.ago..).group('feed_tanks.feed').count
  end

  def stale_counts
    @stale_counts ||= FeedTank.where(ignored: false).where.not(tank_id: nil)
                              .where('last_read_at IS NULL OR last_read_at < ?', FeedTank.stale_hours.hours.ago)
                              .group(:feed).count
  end

  # The newest file in from the feed's pickup job or a manual import.
  def last_logs
    @last_logs ||= FeedTank::FEEDS.keys.index_with do |feed|
      names = [FeedTanksController::PROCESSES[feed], TankFeedImportsController.process_name(feed)].compact
      SyncLog.where(process_name: names).order(started_at: :desc).first
    end
  end

  def schedules
    @schedules ||= AutomatedProcessesController::PROCESSES.each_with_object({}) do |process, map|
      feed = FeedTanksController::PROCESSES.key(process[:name])
      map[feed] = AutomatedProcessesController.config_for(process) if feed
    end
  end
end
