class AutomatedProcessConfig < ApplicationRecord
  validates :slug, presence: true, uniqueness: true

  def self.for_slug(slug)
    find_or_create_by!(slug: slug) do |c|
      c.schedule = '0 * * * *'
    end
  end

  def due?
    return false if schedule.blank?
    cron = Fugit.parse_cron(schedule)
    return false unless cron
    next_time = cron.next_time(last_triggered_at || 1.year.ago)
    next_time <= Time.current
  end

  def mark_triggered!
    update!(last_triggered_at: Time.current)
  end
end
