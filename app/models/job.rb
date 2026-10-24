class Job < ApplicationRecord
  JOB_TYPES = %w[Mixing Filling Labeling Packaging Cleanup].freeze

  belongs_to :production_order
  belongs_to :created_by, class_name: 'User'
  belongs_to :edited_by, class_name: 'User', optional: true
  has_many :job_workers, dependent: :destroy
  has_many :users, through: :job_workers

  validates :job_type, inclusion: { in: JOB_TYPES }
  validates :started_at, presence: true
  validate :order_not_voided, on: :create

  # The first clock-in starts a created production order.
  after_create -> { production_order.update!(status: 'in_progress') if production_order.status == 'created' }

  scope :active, -> { where(ended_at: nil) }
  scope :completed, -> { where.not(ended_at: nil) }

  def active?
    ended_at.nil?
  end

  def duration_seconds
    ((ended_at || Time.current) - started_at).to_i
  end

  def duration_formatted
    total = duration_seconds
    hours = total / 3600
    minutes = (total % 3600) / 60
    seconds = total % 60
    format('%02d:%02d:%02d', hours, minutes, seconds)
  end

  # Admin correction of clock times: { job_worker_id => { clocked_in_at:, clocked_out_at: } }.
  # The job's span follows its workers. Raises ActiveRecord::RecordInvalid on bad times.
  def correct_times!(times, user)
    transaction do
      job_workers.each do |jw|
        attrs = times[jw.id.to_s]
        jw.update!(clocked_in_at: attrs[:clocked_in_at], clocked_out_at: attrs[:clocked_out_at]) if attrs
      end
      update!(started_at: job_workers.minimum(:clocked_in_at), ended_at: job_workers.maximum(:clocked_out_at),
              edited_by: user, edited_at: Time.current)
    end
  end

  def clock_out!
    now = Time.current
    transaction do
      update!(ended_at: now)
      job_workers.update_all(clocked_out_at: now)
    end
  end

  private

  def order_not_voided
    errors.add(:production_order, 'is voided') if production_order&.voided?
  end
end
