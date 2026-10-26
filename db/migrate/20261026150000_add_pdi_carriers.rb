class AddPdiCarriers < ActiveRecord::Migration[7.2]
  def change
    create_table :pdi_carriers do |t|
      t.string :pdi_carrier_id, null: false
      t.string :name, null: false
      t.boolean :active, default: true, null: false
      t.timestamps
    end
    add_index :pdi_carriers, :pdi_carrier_id, unique: true

    add_column :customer_orders, :pdi_carrier_id, :string
    add_index :customer_orders, :pdi_carrier_id
  end
end
