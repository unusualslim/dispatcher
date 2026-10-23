class InventoryCostHistory < ApplicationRecord
  belongs_to :product, primary_key: :id
end
