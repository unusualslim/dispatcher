class ProductionOrder < ApplicationRecord
  # created: planned, nothing done yet · in_progress: a crew has clocked in · completed: done
  STATUSES = %w[created in_progress completed].freeze
  OPEN_STATUSES = %w[created in_progress].freeze

  belongs_to :product, optional: true
  belongs_to :customer, optional: true
  belongs_to :location, optional: true

  has_many :production_order_components, -> { order(:position, :id) }, dependent: :destroy
  accepts_nested_attributes_for :production_order_components, allow_destroy: true, reject_if: :all_blank

  has_many :production_order_batches, dependent: :destroy
  has_many :jobs, dependent: :destroy
  has_many :ledger_entries, dependent: :restrict_with_error
  accepts_nested_attributes_for :production_order_batches,
                                allow_destroy: true,
                                reject_if: :all_blank

  validates :status, inclusion: { in: STATUSES }, allow_blank: true
  validates :number, presence: true, uniqueness: true

  before_validation :set_default_status, on: :create
  before_validation :generate_number, on: :create
  before_validation :sync_customer_location_names
  before_save :stamp_date_completed, if: -> { will_save_change_to_status? && status == 'completed' }
  after_update_commit -> { ProductionGlPosting.status_changed(self) }, if: :saved_change_to_status?

  scope :search, lambda { |term|
    return all if term.blank?

    pattern = "%#{term.strip.downcase}%"
    where(
      'LOWER(item) LIKE :p OR LOWER(batch_number) LIKE :p OR LOWER(customer_name) LIKE :p OR LOWER(location_name) LIKE :p OR LOWER(number) LIKE :p',
      p: pattern
    )
  }

  scope :by_location, lambda { |location_name|
    return all if location_name.blank?

    where('LOWER(location_name) LIKE ?', "%#{location_name.strip.downcase}%")
  }

  scope :due_between, lambda { |from_str, to_str|
    from = from_str.present? ? (Date.parse(from_str) rescue nil) : nil
    to   = to_str.present?   ? (Date.parse(to_str)   rescue nil) : nil

    return all if from.nil? && to.nil?
    return where('due_date >= ?', from) if to.nil?
    return where('due_date <= ?', to)   if from.nil?

    where(due_date: from..to)
  }

  scope :ordered_default, -> { order(due_date: :desc, id: :desc) }

  scope :by_status, lambda { |status|
    s = status.to_s.strip.downcase
    return all if s.blank? || s == 'all'

    where(status: s)
  }

  def build_components_from_bom!
    return if product.blank? || qty_to_make.blank?

    production_order_components.destroy_all

    product.product_components.includes(:component_product).each_with_index do |pc, idx|
      production_order_components.build(
        position: idx + 1,
        quantity: (pc.quantity_per_unit.to_d * qty_to_make.to_d),
        uom: pc.uom.presence || '',
        part_number: pc.component_product&.id,
        description: pc.component_product&.name,
        product_id: pc.component_product&.id
      )
    end
  end

  private

  def sync_customer_location_names
    self.customer_name = customer&.name if customer_id.present?
    self.location_name = location&.company_name if location_id.present?
  end

  def stamp_date_completed
    self.date_completed ||= Time.zone.today
  end

  def set_default_status
    self.status ||= 'created'
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
