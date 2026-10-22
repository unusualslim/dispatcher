class Quote < ApplicationRecord
  belongs_to :customer
  belongs_to :location, optional: true
  belongs_to :customer_order, optional: true
  belongs_to :accepted_by, class_name: 'User', optional: true
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

  # Overall lock state for display: :active, :scheduled, :expired, or nil
  # (not accepted / not a price-locking quote). Individual lines may be superseded.
  def lock_status(date = Date.today)
    return nil unless locks_pricing? && accepted?
    return :scheduled if valid_from > date
    return :expired   if expiry_date < date
    :active
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
          .where('quote_products.superseded_on IS NULL OR quote_products.superseded_on > ?', valid_from)
          .update_all(superseded_on: valid_from, updated_at: Time.current)
      end

      update!(status: 'accepted', accepted_at: Time.current, accepted_by: user)
    end
  end

  # Build an unsaved order at this quote's prices, linked back to the quote lines.
  # Used to pre-fill the new order form; the user sets quantities and saves.
  def build_order
    order = CustomerOrder.new(
      customer:     customer,
      location:     location,
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
