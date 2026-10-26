class AppSetting < ApplicationRecord
  DEFAULTS = {
    'labor_rate' => '25.00',
    'mrp_purchase_lead_days' => '7',
    'mrp_production_days' => '1',
    'mrp_customer_lead_days' => '3'
  }.freeze

  MRP_KEYS = %w[mrp_purchase_lead_days mrp_production_days mrp_customer_lead_days].freeze

  validates :key, presence: true, uniqueness: true

  def self.get(key)
    find_by(key: key)&.value || DEFAULTS[key.to_s]
  end

  def self.set(key, value)
    find_or_initialize_by(key: key).update!(value: value)
  end

  # Hourly rate applied to /line crew-hours (standard and actual).
  def self.labor_rate
    get('labor_rate').to_d
  end

  # MRP defaults (days) for products, vendors and customers without their own lead time.
  def self.mrp_days(key)
    get(key).to_i
  end
end
