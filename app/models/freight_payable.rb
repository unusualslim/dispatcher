# What we owe a carrier for freight: from a PO's separate carrier, the carrier cost on a customer order, or a
# dispatch priced per load (farthest stop).
# Starts accrued (the estimate) and becomes invoiced once the carrier's invoice number and amount are entered.
# Five Points Logistics / Service payables are intercompany (FPL bills FPS for the haul).
class FreightPayable < ApplicationRecord
  STATUSES = %w[accrued invoiced].freeze

  belongs_to :source, polymorphic: true
  belongs_to :vendor

  normalizes :invoice_no, :bol_number, with: ->(value) { value.strip.presence }

  validates :status, inclusion: { in: STATUSES }
  validates :amount, numericality: true, allow_nil: true
  validates :vendor_id, uniqueness: { scope: %i[source_type source_id] }

  before_validation :set_status

  scope :accrued, -> { where(status: 'accrued') }
  scope :invoiced, -> { where(status: 'invoiced') }

  # Creates or refreshes the payable for one source and carrier. An invoiced payable keeps its invoice; only the
  # accrual moves, so the difference shows as a variance.
  def self.sync!(source, vendor_id, accrued_amount, bol_number: nil)
    payable = find_or_initialize_by(source: source, vendor_id: vendor_id)
    payable.accrued_amount = accrued_amount
    payable.bol_number = bol_number if bol_number.present?
    payable.save!
    payable
  end

  def intercompany? = CustomerOrder::DISPATCH_CARRIER_IDS.include?(vendor_id)
  def invoiced? = status == 'invoiced'

  # What we owe: the invoice once entered, else the accrual.
  def balance = invoiced? ? amount.to_d : accrued_amount.to_d

  # Invoice minus the accrual (positive = the carrier billed more than we accrued).
  def variance
    amount.to_d - accrued_amount.to_d if invoiced? && accrued_amount
  end

  def source_label
    case source
    when PurchaseOrder then "PO #{source.display_number}"
    when CustomerOrder then "Order #{source.external_order_no.presence || "##{source.id}"}"
    when Dispatch then "Dispatch ##{source.id}"
    end
  end

  private

  def set_status
    self.status = invoice_no.present? && amount.present? ? 'invoiced' : 'accrued'
  end
end
