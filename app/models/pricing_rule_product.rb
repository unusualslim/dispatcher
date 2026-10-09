class PricingRuleProduct < ApplicationRecord
  belongs_to :pricing_rule
  belongs_to :product
end
