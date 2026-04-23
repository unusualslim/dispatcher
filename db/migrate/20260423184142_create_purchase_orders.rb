class CreatePurchaseOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :purchase_orders do |t|
      t.references :vendor, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.decimal :unit_cost, precision: 12, scale: 4
      t.string :status, default: 'draft', null: false
      t.string :trigger_type
      t.text :trigger_reason
      t.bigint :approved_by_id
      t.datetime :submitted_at
      t.date :expected_delivery_date
      t.datetime :received_at
      t.bigint :received_by_id
      t.text :notes
      t.timestamps
    end

    add_index :purchase_orders, :status
    add_index :purchase_orders, :trigger_type
  end
end
