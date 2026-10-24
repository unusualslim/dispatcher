class AppSetting < ApplicationRecord
  DEFAULTS = {
    'labor_rate' => '25.00'
  }.freeze

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
end
