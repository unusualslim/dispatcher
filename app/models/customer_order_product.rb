class CustomerOrderProduct < ApplicationRecord
  belongs_to :customer_order
  belongs_to :product, optional: true
  # What priced this line: a locked quote price, or a dynamic pricing rule.
  belongs_to :quote_product, optional: true
  belongs_to :pricing_rule,  optional: true
  # The warehouse the line ships from (PDI's site on the line); `warehouse` keeps PDI's site ID.
  belongs_to :location, optional: true

  # PDI sites that ship straight from a third party: no stock of ours moves, so MRP leaves them out.
  # 7777 Dropship - Third Party WH, 1331 Atmus.
  DROPSHIP_SITES = %w[7777 1331].freeze

  def dropship? = DROPSHIP_SITES.include?(warehouse)

  PRICE_MISMATCHES = %w[lock_mismatch rule_mismatch].freeze
  scope :price_mismatches, -> { where(price_check: PRICE_MISMATCHES) }

  validates :quantity, numericality: true, allow_nil: true
  # PDI-imported orders can carry credits and adjustments (e.g. a -0.01 non-inventory line).
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true,
                    unless: -> { customer_order&.external_order_no.present? }

  # Imported lines are price-checked; keep the flag current when the price is edited here.
  after_save :recheck_price, if: -> { price_checked_at && (saved_change_to_price? || saved_change_to_product_id?) }

  # PDI price minus the expected (locked or rule) price.
  def price_variance
    price.to_d - expected_price if price && expected_price
  end

  def price_mismatch? = PRICE_MISMATCHES.include?(price_check)

  private

  def recheck_price
    order = customer_order
    PriceCheckService.check_line!(self, order: order, date: (order.order_date || order.created_at).to_date)
  end
end
