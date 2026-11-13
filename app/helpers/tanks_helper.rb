# Formatting for tank pages: gallons, Eastern reading times and stale styling.
module TanksHelper
  def gallons(value)
    value.nil? ? '—' : "#{number_with_delimiter(value.round)} gal"
  end

  # "Nov 11 6:00 AM" in Eastern, with "(2 days ago)" when older than a day.
  def reading_time(time)
    return '—' unless time

    local = time.in_time_zone(TankFeeds::Base::EASTERN)
    text = local.strftime('%b %-d %-l:%M %p')
    time < 1.day.ago ? "#{text} (#{time_ago_in_words(time)} ago)" : text
  end

  # 2198.0 → 2198 for form fields; 2198.5 stays.
  def plain_number(value)
    return if value.nil?

    (value % 1).zero? ? value.to_i : value
  end

  def stale_class(time)
    'text-muted fst-italic' if time.nil? || time < FeedTank.stale_hours.hours.ago
  end

  def feed_tank_summary(feed_tank)
    d = feed_tank.details
    [d['location'] || d['customer'], d['city'], d['product'] || d['content'],
     d['capacity'] && "#{d['capacity']} gal"].compact_blank.join(' · ')
  end
end
