class CreateInventoryTransactions < ActiveRecord::Migration[7.0]
  def change
    create_table :inventory_transactions do |t|
      t.references :product, null: false, foreign_key: true
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.string :direction, null: false
      t.string :transactable_type
      t.bigint :transactable_id
      t.string :reference_number
      t.text :notes
      t.bigint :created_by_id
      t.timestamps
    end

    add_index :inventory_transactions, [:transactable_type, :transactable_id], name: 'idx_inv_trans_on_transactable'
    add_index :inventory_transactions, :created_by_id
  end
end
