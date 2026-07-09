class QuoteProduct < ApplicationRecord
  belongs_to :quote
  belongs_to :product, foreign_key: :product_id, primary_key: :id, optional: true

  def line_total
    (quantity || 0) * (price || 0)
  end
end
