class Quote < ApplicationRecord
  belongs_to :customer
  belongs_to :location, optional: true
  belongs_to :customer_order, optional: true
  has_many :quote_products, dependent: :destroy
  accepts_nested_attributes_for :quote_products, allow_destroy: true, reject_if: :all_blank

  STATUSES = %w[draft sent accepted rejected].freeze

  validates :status, inclusion: { in: STATUSES }

  before_create :assign_quote_number

  def total
    quote_products.sum { |qp| (qp.quantity || 0) * (qp.price || 0) }
  end

  def draft?    = status == 'draft'
  def sent?     = status == 'sent'
  def accepted? = status == 'accepted'
  def rejected? = status == 'rejected'

  private

  def assign_quote_number
    last = Quote.where("quote_number LIKE 'Q-%'")
                .order(Arel.sql("CAST(SUBSTRING(quote_number FROM 3) AS INTEGER) DESC"))
                .first
    next_num = last ? last.quote_number.sub('Q-', '').to_i + 1 : 1001
    self.quote_number = "Q-#{next_num}"
  end
end
