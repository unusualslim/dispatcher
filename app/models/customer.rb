class Customer < ApplicationRecord
  has_many :phone_numbers, dependent: :destroy
  accepts_nested_attributes_for :phone_numbers, allow_destroy: true
  has_many :customer_locations, dependent: :destroy
  has_many :customer_orders, dependent: :nullify
  has_many :pricing_rules, dependent: :destroy
  has_many :quotes
  has_many :locations, through: :customer_locations

  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }

  validates :preferred_contact_method, inclusion: { in: ['no preference', 'phone', 'email'] }

  # Inactive customers (set by hand or from PDI's AccountStatus) stay on their history but leave pickers.
  scope :active, -> { where(active: true) }

  # Picker list: active customers plus any already chosen, so editing a record never drops its customer.
  def self.selectable(*keep_ids)
    active.or(where(id: keep_ids.flatten.compact))
  end
end
