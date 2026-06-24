class SyncLog < ApplicationRecord
  STATUSES = %w[running success failed].freeze

  scope :recent, -> { order(started_at: :desc) }
  scope :for_process, ->(name) { where(process_name: name).order(started_at: :desc) }

  def duration
    return nil unless started_at && completed_at
    completed_at - started_at
  end

  def duration_s
    d = duration
    return '—' unless d
    d < 60 ? "#{d.round(1)}s" : "#{(d / 60).round(1)}m"
  end
end
