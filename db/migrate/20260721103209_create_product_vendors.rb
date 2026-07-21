class CreateProductVendors < ActiveRecord::Migration[7.0]
  def change
    create_table :product_vendors do |t|
      t.string :product_id, null: false
      t.string :vendor_id, null: false
      t.integer :priority, null: false, default: 1
      t.timestamps
    end
    add_foreign_key :product_vendors, :products
    add_foreign_key :product_vendors, :vendors
    add_index :product_vendors, [:product_id, :vendor_id], unique: true
    add_index :product_vendors, [:product_id, :priority]
  end
end
