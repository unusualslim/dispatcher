class CreatePricingRuleProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :pricing_rule_products do |t|
      t.integer :pricing_rule_id
      t.string :product_id

      t.timestamps
    end
  end
end
