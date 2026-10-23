class QuoteProduct < ApplicationRecord
  belongs_to :quote
  belongs_to :product, primary_key: :id, optional: true
  belongs_to :pricing_rule, optional: true
  has_many :customer_order_products, dependent: :nullify

  validates :product_id, presence: true, if: -> { quote&.locks_pricing? }
  validates :price, numericality: { greater_than_or_equal_to: 0 }, allow_nil: true

  before_save :snapshot_pricing, unless: -> { quote&.accepted? }

  # Lines whose price is locked for the customer on the given date.
  # A superseded line stops locking the day before its replacement starts;
  # a quote whose lock was ended early stops on lock_ended_on.
  scope :locking_on, lambda { |date|
    joins(:quote)
      .merge(Quote.accepted_locks)
      .where('quotes.valid_from <= ? AND quotes.expiry_date >= ?', date, date)
      .where('quotes.lock_ended_on IS NULL OR quotes.lock_ended_on > ?', date)
      .where('quote_products.superseded_on IS NULL OR quote_products.superseded_on > ?', date)
  }

  def self.active_lock_for(customer, product, date: Date.today)
    customer_id = customer.is_a?(Customer) ? customer.id : customer
    return nil if customer_id.blank? || product.blank?

    locking_on(date)
      .where(quotes: { customer_id: customer_id })
      .where(product_id: product.is_a?(Product) ? product.id : product)
      .order('quotes.valid_from DESC, quotes.accepted_at DESC')
      .first
  end

  def line_total
    (quantity || 0) * (price || 0)
  end

  # Last day this line's price is locked (nil if it doesn't lock).
  def locked_through
    last = quote.lock_last_day
    return nil unless last

    superseded_on ? [last, superseded_on - 1].min : last
  end

  def lock_status(date = Date.today)
    return nil unless quote.locks_pricing? && quote.accepted?
    return :ended      if quote.lock_ended_on && quote.lock_ended_on <= date
    return :superseded if superseded_on && superseded_on <= date
    return :scheduled  if quote.valid_from > date
    return :expired    if quote.expiry_date < date

    :active
  end

  # The price the line's rule produces today (nil if no rule or no price).
  def rule_price(date: Date.today)
    pricing_rule && product && pricing_rule.calculated_price(product, date: date)
  end

  private

  # Record how the price was reached. Runs on every save while the quote is
  # still editable, so the snapshot reflects costs at the time it was quoted.
  def snapshot_pricing
    self.product_name = product.name if product
    self.priced_at = Time.current
    if pricing_rule && product
      self.pricing_basis    = pricing_rule.pricing_basis
      self.pricing_method   = pricing_rule.pricing_method
      self.rule_value       = pricing_rule.value
      self.basis_cost       = pricing_rule.basis_cost(product)
      self.price_overridden = rule_price.nil? || price.to_d.round(4) != rule_price.round(4)
    else
      self.pricing_basis = self.pricing_method = self.rule_value = self.basis_cost = nil
      self.price_overridden = false
    end
  end
end
