class CreateStandardCostHistories < ActiveRecord::Migration[7.0]
  def change
    create_table :standard_cost_histories do |t|
      t.string :product_id
      t.decimal :amount, precision: 12, scale: 4
      t.date :effective_date
      t.integer :created_by_id

      t.timestamps
    end
  end
end
