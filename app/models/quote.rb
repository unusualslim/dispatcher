class Quote < ApplicationRecord
  belongs_to :customer
  belongs_to :location, optional: true
  belongs_to :customer_order, optional: true
  belongs_to :accepted_by, class_name: 'User', optional: true
  belongs_to :lock_ended_by, class_name: 'User', optional: true
  has_many :quote_products, dependent: :destroy
  accepts_nested_attributes_for :quote_products, allow_destroy: true, reject_if: :all_blank

  STATUSES = %w[draft sent accepted rejected].freeze

  # Validity presets offered on the quote form: label => ->(start_date) { end_date }
  DURATION_PRESETS = {
    'End of month'   => ->(d) { d.end_of_month },
    'End of quarter' => ->(d) { d.end_of_quarter },
    '30 days'        => ->(d) { d + 29 },
    '60 days'        => ->(d) { d + 59 },
    '90 days'        => ->(d) { d + 89 },
  }.freeze

  validates :status, inclusion: { in: STATUSES }
  validates :valid_from, :expiry_date, presence: true, if: :locks_pricing?
  validate  :valid_window

  before_create :assign_quote_number

  # Quotes created before price locking existed keep locks_pricing = false
  # and never lock prices.
  scope :accepted,       -> { where(status: 'accepted') }
  scope :accepted_locks, -> { accepted.where(locks_pricing: true) }

  def total
    quote_products.sum { |qp| (qp.quantity || 0) * (qp.price || 0) }
  end

  def draft?    = status == 'draft'
  def sent?     = status == 'sent'
  def accepted? = status == 'accepted'
  def rejected? = status == 'rejected'
  def editable? = draft? || sent?

  # Overall lock state for display: :active, :scheduled, :expired, :ended, or nil
  # (not accepted / not a price-locking quote). Individual lines may be superseded.
  def lock_status(date = Date.today)
    return nil unless locks_pricing? && accepted?
    return :ended     if lock_ended_on && lock_ended_on <= date
    return :scheduled if valid_from > date
    return :expired   if expiry_date < date
    :active
  end

  def lock_endable? = %i[active scheduled].include?(lock_status)

  # Orders can be created at the quoted prices while the lock is (or will be)
  # in effect, or from an accepted quote that never locked prices.
  def orderable? = accepted? && (!locks_pricing? || lock_endable?)

  # Last day the quote's prices are locked, accounting for an early end.
  def lock_last_day
    return nil unless locks_pricing? && expiry_date
    lock_ended_on ? [expiry_date, lock_ended_on - 1].min : expiry_date
  end

  # End the price lock early. From `on` (today or later), orders for this
  # customer are priced from the live rules again; orders already priced keep
  # their prices. expiry_date is left as quoted to the customer.
  def end_lock!(user, on: Date.today, reason: nil)
    raise ArgumentError, "This quote's prices aren't locked" unless lock_endable?

    self.lock_ended_on   = on
    self.lock_ended_at   = Time.current
    self.lock_ended_by   = user
    self.lock_end_reason = reason.presence
    validate_lock_end
    if errors.any?
      # Keep the error messages but don't leave a rejected end date on the record.
      restore_attributes(%w[lock_ended_on lock_ended_at lock_ended_by_id lock_end_reason])
      raise ActiveRecord::RecordInvalid, self
    end
    save!
  end

  # Accept the quote and lock its prices. Any active or scheduled lock this
  # customer already has on the same product ends the day before this one starts.
  def accept!(user)
    transaction do
      if locks_pricing?
        product_ids = quote_products.map(&:product_id).compact
        QuoteProduct
          .joins(:quote)
          .merge(Quote.accepted_locks)
          .where(quotes: { customer_id: customer_id })
          .where.not(quote_id: id)
          .where(product_id: product_ids)
          .where('quotes.expiry_date >= ?', valid_from)
          .where('quotes.lock_ended_on IS NULL OR quotes.lock_ended_on > ?', valid_from)
          .where('quote_products.superseded_on IS NULL OR quote_products.superseded_on > ?', valid_from)
          .update_all(superseded_on: valid_from, updated_at: Time.current)
      end

      update!(status: 'accepted', accepted_at: Time.current, accepted_by: user)
    end
  end

  # A draft replacement quote for the same customer and products at today's rule
  # prices, for the same length of validity starting today. Lines with no
  # applicable rule keep their current price. Accepting it replaces this lock.
  def create_requote!(review_lines)
    days = valid_from && expiry_date ? (expiry_date - valid_from).to_i : 29
    changes = review_lines.select(&:cost_change).map do |l|
      pct = l.cost_change_pct ? format(' (%+.1f%%)', l.cost_change_pct) : ''
      "#{l.product.name}: cost #{format('%+.4f', l.cost_change)}#{pct} since #{l.since.strftime('%b %-d')}"
    end

    Quote.create!(
      customer: customer, location: location, locks_pricing: true,
      valid_from: Date.today, expiry_date: Date.today + days,
      notes: (["Re-quote of #{quote_number}.", *changes].join("\n")),
      quote_products_attributes: quote_products.select(&:product).map { |qp|
        result = PricingRuleService.rule_lookup(customer_id, qp.product)
        { product_id: qp.product_id, quantity: qp.quantity,
          price: result&.dig(:price) || qp.price, pricing_rule_id: (result[:rule]&.id if result&.dig(:price)) }
      }
    )
  end

  # Build an unsaved order at this quote's prices, linked back to the quote lines.
  # Used to pre-fill the new order form; the user sets quantities and saves.
  def build_order
    order = CustomerOrder.new(
      customer:     customer,
      location:     location || customer.locations.first,
      order_status: :open_order,
      notes:        "Created from Quote #{quote_number}"
    )

    quote_products.each do |qp|
      order.customer_order_products.build(
        product_id:    qp.product_id,
        product_name:  qp.product_name,
        quantity:      qp.quantity,
        price:         qp.price,
        quote_product: (qp if locks_pricing?)
      )
    end
    order
  end

  private

  def validate_lock_end
    if lock_ended_on.nil?
      errors.add(:lock_ended_on, "is required")
    elsif lock_ended_on < Date.today
      errors.add(:lock_ended_on, "can't be in the past — orders already priced keep their prices")
    elsif lock_ended_on > expiry_date
      errors.add(:lock_ended_on, "is after the quote already expires (#{expiry_date.strftime('%b %-d, %Y')})")
    end
  end

  def valid_window
    return unless valid_from && expiry_date
    errors.add(:expiry_date, "must be on or after the valid from date") if expiry_date < valid_from
  end

  def assign_quote_number
    last = Quote.where("quote_number LIKE 'Q-%'")
                .order(Arel.sql("CAST(SUBSTRING(quote_number FROM 3) AS INTEGER) DESC"))
                .first
    next_num = last ? last.quote_number.sub('Q-', '').to_i + 1 : 1001
    self.quote_number = "Q-#{next_num}"
  end
end
