class JobWorker < ApplicationRecord
  belongs_to :job
  belongs_to :user

  validates :clocked_in_at, presence: true
  validate :clocks_out_after_clocking_in

  def duration_seconds
    ((clocked_out_at || Time.current) - clocked_in_at).to_i
  end

  def hours
    duration_seconds / 3600.0
  end

  def duration_formatted
    total = duration_seconds
    hours = total / 3600
    minutes = (total % 3600) / 60
    seconds = total % 60
    format('%02d:%02d:%02d', hours, minutes, seconds)
  end

  private

  def clocks_out_after_clocking_in
    return unless clocked_in_at && clocked_out_at && clocked_out_at <= clocked_in_at

    errors.add(:clocked_out_at, 'must be after clocking in')
  end
end
