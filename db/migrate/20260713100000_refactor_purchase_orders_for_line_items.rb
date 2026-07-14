class RefactorPurchaseOrdersForLineItems < ActiveRecord::Migration[7.0]
  def up
    create_table :purchase_order_line_items do |t|
      t.references :purchase_order, null: false, foreign_key: true
      t.string     :product_id
      t.string     :product_name
      t.decimal    :quantity,     precision: 14, scale: 3
      t.decimal    :unit_cost,    precision: 12, scale: 4
      t.string     :package_code
      t.timestamps
    end
    add_index :purchase_order_line_items, :product_id

    # Preserve existing single-product PO data as line items
    execute <<~SQL
      INSERT INTO purchase_order_line_items
        (purchase_order_id, product_id, product_name, quantity, unit_cost, created_at, updated_at)
      SELECT id, product_id, product_name, quantity, unit_cost, NOW(), NOW()
      FROM purchase_orders
      WHERE quantity IS NOT NULL AND quantity > 0
    SQL

    add_column :purchase_orders, :pdi_reference, :string
    add_column :purchase_orders, :posted_at,     :datetime
    add_index  :purchase_orders, :pdi_reference, unique: true

    remove_column :purchase_orders, :quantity,     :decimal
    remove_column :purchase_orders, :unit_cost,    :decimal
    remove_column :purchase_orders, :product_id,   :string
    remove_column :purchase_orders, :product_name, :string
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
