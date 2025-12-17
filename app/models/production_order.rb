class ProductionOrder < ApplicationRecord
  STATUSES = %w[pending in_progress completed].freeze

  belongs_to :product, optional: true
  belongs_to :customer, optional: true
  belongs_to :location, optional: true


  has_many :production_order_components, -> { order(:position, :id) }, dependent: :destroy
  accepts_nested_attributes_for :production_order_components, allow_destroy: true

  validates :status, inclusion: { in: STATUSES }, allow_blank: true
  validates :number, presence: true, uniqueness: true

  before_validation :set_default_status, on: :create
  before_validation :generate_number, on: :create
  before_validation :sync_customer_location_names

  scope :search, ->(term) {
    return all if term.blank?
    pattern = "%#{term.strip.downcase}%"
    where(
      "LOWER(item) LIKE :p OR LOWER(batch_number) LIKE :p OR LOWER(customer_name) LIKE :p OR LOWER(location_name) LIKE :p OR LOWER(number) LIKE :p",
      p: pattern
    )
  }

  scope :by_location, ->(location_name) {
    return all if location_name.blank?
    where("LOWER(location_name) LIKE ?", "%#{location_name.strip.downcase}%")
  }

  scope :due_between, ->(from_str, to_str) {
    from = from_str.present? ? (Date.parse(from_str) rescue nil) : nil
    to   = to_str.present?   ? (Date.parse(to_str)   rescue nil) : nil

    return all if from.nil? && to.nil?
    return where("due_date >= ?", from) if to.nil?
    return where("due_date <= ?", to)   if from.nil?
    where(due_date: from..to)
  }

  scope :ordered_default, -> { order(due_date: :asc, id: :asc) }

    scope :by_status, ->(status) {
    s = status.to_s.strip.downcase
    return all if s.blank? || s == "all"
    where(status: s)
    }


  private

  def sync_customer_location_names
    self.customer_name = customer&.name if customer_id.present?
    self.location_name = location&.company_name if location_id.present?
  end

  def set_default_status
    self.status ||= "pending"
  end

  def generate_number
    return if number.present?

    loop do
      self.number = self.class.generate_code
      break unless self.class.exists?(number: number)
    end
  end

  def self.generate_code
    # Excludes O, I, 0, 1 to avoid confusion
    charset = %w[
      A B C D E F G H J K L M N P Q R S T U V W X Y Z
      2 3 4 5 6 7 8 9
    ]

    Array.new(6) { charset.sample }.join
  end
end
