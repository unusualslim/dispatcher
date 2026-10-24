class User < ApplicationRecord
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable

  EMPLOYMENT_TYPES = { 'full_time' => 'Full-time', 'temp' => 'Temp' }.freeze

  # Validations
  validates :email, presence: true, uniqueness: true
  validates :employment_type, inclusion: { in: EMPLOYMENT_TYPES.keys }

  has_many :dispatches, foreign_key: :driver_id, dependent: :nullify
  has_many :user_favorites, dependent: :destroy
  has_many :job_workers, dependent: :destroy
  has_many :jobs, through: :job_workers

  # Scope to filter workers
  scope :workers, -> { where(role: 'worker') }
  scope :line_workers, -> { where(role: 'line_worker') }

  def full_name
    "#{first_name} #{last_name}"
  end
end
