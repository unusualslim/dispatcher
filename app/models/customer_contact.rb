# A person at a customer. PDI contacts (source pdi) come from master data and are kept in step with it; ticking
# invoice_recipient marks who gets invoices and statements (PDI has no role for that), and survives syncs.
class CustomerContact < ApplicationRecord
  include Audited

  audited

  SOURCES = %w[app pdi].freeze

  belongs_to :customer

  validates :source, inclusion: { in: SOURCES }
  validate :name_or_email

  scope :active, -> { where(active: true) }
  scope :invoice_recipients, -> { active.where(invoice_recipient: true).where.not(email: [nil, '']) }

  def name = [first_name, last_name].compact_blank.join(' ')
  def label = [name.presence, email.presence].compact.join(' · ')

  # Same person: same email, else same name (PDI contacts carry no ID).
  def match_key = self.class.match_key(first_name, last_name, email)

  def self.match_key(first, last, email)
    email.present? ? "e:#{email.strip.downcase}" : "n:#{[first, last].compact_blank.join(' ').downcase.squish}"
  end

  private

  def name_or_email
    errors.add(:base, 'Give a name or an email.') if name.blank? && email.blank?
  end
end
