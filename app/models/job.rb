class Job < ApplicationRecord
  JOB_TYPES = %w[Mixing Filling Labeling Packaging Cleanup].freeze

  belongs_to :production_order
  belongs_to :created_by, class_name: 'User'
  has_many :job_workers, dependent: :destroy
  has_many :users, through: :job_workers

  validates :job_type, inclusion: { in: JOB_TYPES }
  validates :started_at, presence: true

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

  def clock_out!
    now = Time.current
    transaction do
      update!(ended_at: now)
      job_workers.update_all(clocked_out_at: now)
    end
  end
end
