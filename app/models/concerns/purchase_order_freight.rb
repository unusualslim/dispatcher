# Freight on a purchase order. The freight amount is spread over the lines (by quantity or by value) into each
# line's landed cost, which is what posts to inventory. Freight billed by a separate carrier becomes a payable
# with the carrier's invoice number, date and BOL; an estimate can be accrued until the invoice arrives.
#
# POs imported from PDI have no allocation method, so their receipts post at line cost as before.
module PurchaseOrderFreight
  extend ActiveSupport::Concern

  ALLOCATIONS = { 'quantity' => 'By quantity', 'value' => 'By value' }.freeze
  SOURCES = { 'vendor_invoice' => "On the vendor's invoice", 'carrier' => 'Separate carrier' }.freeze

  included do
    belongs_to :freight_vendor, class_name: 'Vendor', optional: true
    has_many :freight_payables, as: :source, dependent: :destroy

    normalizes :freight_vendor_id, :freight_allocation, :freight_bol, with: ->(value) { value.strip.presence }

    validates :freight_allocation, inclusion: { in: ALLOCATIONS.keys }, allow_nil: true
    validates :freight_source, inclusion: { in: SOURCES.keys }
    validates :freight_vendor, presence: true, if: -> { freight_source == 'carrier' && freight_amount.to_d.positive? }
  end

  def freight_from_carrier? = freight_source == 'carrier'

  # Freight set up on the PO's Freight card. The PDI PO import keeps the app's amount for these.
  def freight_managed_in_app? = freight_allocation.present? || freight_from_carrier? || freight_accrued?
  def freight_landed? = freight_allocation.present? && freight_amount.to_d.positive?

  def freight_payable
    freight_payables.find { |p| p.vendor_id == freight_vendor_id } if freight_vendor_id
  end

  # Freight share per line id: { line_id => amount }. The last line takes the rounding.
  def freight_allocations
    return {} unless freight_landed?

    lines = line_items.select { |line| line.product_id.present? && line.quantity.to_d.positive? }
    total = lines.sum { |line| allocation_weight(line) }
    total.positive? ? split_freight(lines, total) : {}
  end

  # Unit cost plus the line's share of freight per unit.
  def landed_unit_cost(line)
    share = freight_allocations[line.id]
    return line.unit_cost unless share && line.quantity.to_d.positive?

    line.unit_cost.to_d + (share / line.quantity.to_d)
  end

  # Keeps the carrier payable in step with the PO: accrues the freight amount for the carrier.
  def sync_freight_payable!
    stale = freight_payables.accrued
    stale = stale.where.not(vendor_id: freight_vendor_id) if carrier_payable?
    stale.destroy_all
    FreightPayable.sync!(self, freight_vendor_id, freight_amount, bol_number: freight_bol) if carrier_payable?
  end

  def carrier_payable? = freight_from_carrier? && freight_vendor_id.present? && freight_amount.to_d.positive?

  private

  def split_freight(lines, total)
    remaining = freight_amount.to_d
    lines.each_with_index.to_h do |line, i|
      share = i == lines.size - 1 ? remaining : (freight_amount.to_d * allocation_weight(line) / total).round(2)
      remaining -= share
      [line.id, share]
    end
  end

  def allocation_weight(line)
    freight_allocation == 'value' ? line.total_cost.to_d : line.quantity.to_d
  end
end
