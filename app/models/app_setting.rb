class AppSetting < ApplicationRecord
  DEFAULTS = {
    'labor_rate' => '25.00',
    'mrp_purchase_lead_days' => '7',
    'mrp_production_days' => '1',
    'mrp_customer_lead_days' => '3',
    'mrp_transfer_days' => '1',
    'samsara_route_start_time' => '08:00',
    'tank_stale_hours' => '30',
    'company.name' => 'Five Points Service, Inc.',
    'company.address' => '10154 US Highway 341',
    'company.city_state_zip' => 'Fort Valley, GA 31030',
    'company.phone' => '(478) 825-5631',
    'company.email' => '',
    'company.website' => 'fivepointsservice.com',
    'company.quote_terms' => 'Prices are per unit and exclude applicable taxes unless stated. Freight is quoted ' \
                             'separately unless included in the price. Please reference the quote number when ordering.'
  }.freeze

  # Company details printed on customer-facing documents (Admin → Company Info).
  COMPANY_KEYS = %w[name address city_state_zip phone email website quote_terms].freeze

  MRP_KEYS = %w[mrp_purchase_lead_days mrp_production_days mrp_customer_lead_days mrp_transfer_days].freeze

  validates :key, presence: true, uniqueness: true

  def self.get(key)
    find_by(key: key)&.value || DEFAULTS[key.to_s]
  end

  def self.set(key, value)
    find_or_initialize_by(key: key).update!(value: value)
  end

  # { 'name' => ..., 'address' => ... } for printouts.
  def self.company
    COMPANY_KEYS.index_with { |key| get("company.#{key}").to_s }
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
