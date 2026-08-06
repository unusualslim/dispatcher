class JobWorker < ApplicationRecord
  belongs_to :job
  belongs_to :user

  def duration_seconds
    ((clocked_out_at || Time.current) - clocked_in_at).to_i
  end

  def duration_formatted
    total = duration_seconds
    hours = total / 3600
    minutes = (total % 3600) / 60
    seconds = total % 60
    format('%02d:%02d:%02d', hours, minutes, seconds)
  end
end
