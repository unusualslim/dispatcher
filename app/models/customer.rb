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

  # PDI's credit snapshot, refreshed from every imported order (and the live credit check):
  # pdi_credit_status "Good" / "Credit Hold", pdi_available_credit = limit minus balance.
  def over_credit?
    pdi_credit_status == 'Credit Hold' || pdi_available_credit&.negative? || false
  end

  # Saves the snapshot when it changed: { pdi_credit_status:, pdi_credit_limit:, pdi_available_credit: }.
  def record_pdi_credit!(credit)
    return if credit.blank?

    assign_attributes(credit)
    return unless changed?

    self.pdi_credit_updated_at = Time.current
    save!
  end

  # Picker list: active customers plus any already chosen, so editing a record never drops its customer.
  def self.selectable(*keep_ids)
    active.or(where(id: keep_ids.flatten.compact))
  end
end
