require 'test_helper'

class PriceIncreaseTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  include ActionMailer::TestHelper

  setup do
    @cap = Product.create!(id: 'PI-CAP', name: 'Cap', standard_cost: 0.1)
    @coolant = Product.create!(id: 'PI-COOL', name: 'Coolant 6/1G', standard_cost: 6)
    ProductComponent.create!(product: @coolant, component_product: @cap, quantity_per_unit: 6)
    @rule = PricingRule.create!(name: 'Coolant 25%', pricing_basis: 'standard_cost', pricing_method: 'margin',
                                value: 25)
    @rule.pricing_rule_products.create!(product: @coolant)
    @customer = Customer.create!(name: 'Parts Central', email: 'buyer@parts.example',
                                 preferred_contact_method: 'no preference')
    @quote = Quote.create!(customer: @customer, status: 'draft', locks_pricing: true, valid_from: Date.current - 10,
                           expiry_date: Date.current + 80)
    @quote.quote_products.create!(product: @coolant, quantity: 100, price: 8, pricing_rule: @rule)
    @admin = User.create!(email: 'pi-admin@example.com', password: 'password123', role: 'admin')
    @quote.accept!(@admin)
    sign_in @admin
  end

  test 'a bulk increase raises the rules, flags locked quotes, and the selected quotes are re-quoted and published' do
    get bulk_increase_pricing_rules_path(component_id: @cap.id, percent: 10)
    assert_select 'td', text: 'Coolant 25%'

    post apply_increase_pricing_rules_path, params: { component_id: @cap.id, percent: 10 }
    assert_in_delta 31.8182, @rule.reload.value.to_f, 0.001 # 1 − 0.75 / 1.1
    assert_redirected_to quote_margin_review_path(status: 'increase')

    line = QuoteMarginReview.for_quote(@quote).first
    assert_equal :increase, line.status
    assert_in_delta 8.8, line.rule_price_now.to_f, 0.001

    effective = Date.current + 14
    assert_enqueued_emails 1 do
      post accept_increases_quote_margin_review_path, params: { quote_ids: [@quote.id], effective_on: effective.iso8601,
                                                                email: '1' }
    end
    requote = Quote.where(customer: @customer).where.not(id: @quote.id).sole
    assert_equal ['accepted', effective, effective + 90], [requote.status, requote.valid_from, requote.expiry_date]
    assert_in_delta 8.8, requote.quote_products.first.price.to_f, 0.001
    assert_equal effective, @quote.quote_products.first.reload.superseded_on
  end
end
