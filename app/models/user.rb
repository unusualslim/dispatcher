class User < ApplicationRecord
  include UserPermissions

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
  has_many :job_workers, dependent: :restrict_with_error # labor history feeds costing and the GL
  has_many :jobs, through: :job_workers
  has_many :dispatch_messages, dependent: :restrict_with_error
  has_many :comments, dependent: :restrict_with_error
  has_many :created_jobs, class_name: 'Job', foreign_key: :created_by_id, inverse_of: :created_by,
                          dependent: :restrict_with_error
  has_many :approved_ledger_entries, class_name: 'LedgerEntry', foreign_key: :approved_by_id,
                                     inverse_of: :approved_by, dependent: :restrict_with_error

  # What keeps this user from being deleted (empty when they have no history).
  def history_reasons
    { 'line clock records' => job_workers, 'line jobs started' => created_jobs, 'driver messages' => dispatch_messages,
      'comments' => comments, 'posted GL entries' => approved_ledger_entries }.select { |_, rel| rel.exists? }.keys
  end

  scope :active, -> { where(deactivated_at: nil) }
  scope :inactive, -> { where.not(deactivated_at: nil) }
  # Active drivers and line workers (for pickers and the /line grid)
  scope :workers, -> { active.where(role: 'worker') }
  scope :line_workers, -> { active.where(role: 'line_worker') }

  def active?
    deactivated_at.nil?
  end

  # Devise: inactive users can't sign in, and signed-in sessions end on their next request.
  def active_for_authentication?
    super && active?
  end

  def inactive_message
    active? ? super : :deactivated
  end

  def full_name
    "#{first_name} #{last_name}"
  end
end
