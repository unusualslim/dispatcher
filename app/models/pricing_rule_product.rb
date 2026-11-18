class PricingRuleProduct < ApplicationRecord
  include Audited

  audited

  belongs_to :pricing_rule
  belongs_to :product
end
