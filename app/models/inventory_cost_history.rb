class InventoryCostHistory < ApplicationRecord
  belongs_to :product, foreign_key: :product_id, primary_key: :id
end
