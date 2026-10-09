class CreatePricingRules < ActiveRecord::Migration[7.0]
  def change
    create_table :pricing_rules do |t|
      t.string :name
      t.integer :customer_id
      t.string :pricing_basis
      t.string :pricing_method
      t.decimal :value, precision: 12, scale: 4
      t.date :effective_date
      t.date :expiration_date

      t.timestamps
    end
  end
end
