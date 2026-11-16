# What a batch (lot) label says about a production order, shared by the printed pallet label
# (ProductionOrdersController#batch_labels) and the page its QR code opens (LotScansController).
# The crew uses the made date to pull the oldest pallets first (FIFO).
class BatchLabel
  FORMATS = { 'full' => '1 per 4×6 label', 'quad' => '4 per 4×6 label' }.freeze
  MAX_LABELS = 100

  attr_reader :order

  delegate :voided?, to: :order

  def self.for_lot(lot_number)
    order = ProductionOrder.where(lot_number: lot_number.to_s.strip)
                           .order(Arel.sql('voided_at IS NULL DESC'), id: :desc).first
    order && new(order)
  end

  def initialize(order)
    @order = order
  end

  def lot = order.lot_number
  def product_name = order.product&.name.presence || order.item.presence || 'Unknown product'
  def product_code = order.product_id
  def warehouse = order.location

  # When it was made: completion date, else the planned production date, else the start.
  def made_on
    order.date_completed || order.production_date || order.date_started
  end

  def age_in_days
    made_on && (Time.zone.today - made_on).to_i
  end

  # PDI's batch number(s), shown alongside the app's lot until PDI is out of the picture.
  def pdi_batches
    [order.batch_number, *order.production_order_batches.map(&:batch_number)].compact_blank.uniq
  end

  def quantity = order.total_qty_produced

  def status_label
    case order.status
    when 'completed' then 'Completed'
    when 'quality_check' then 'In quality check'
    when 'voided' then 'Voided'
    else order.status.to_s.humanize
    end
  end
end
