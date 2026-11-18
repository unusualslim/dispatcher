# Several costs and part numbers per item from one vendor (by package or quantity break), kept on the
# product-vendor link. The operations group's requirement: "several different costs and part numbers for single
# items from one vendor".
class CreateVendorItemPrices < ActiveRecord::Migration[8.1]
  def change
    create_table :vendor_item_prices do |t|
      t.references :product_vendor, null: false, foreign_key: { on_delete: :cascade }
      t.string :vendor_part_number
      t.string :description
      t.decimal :min_quantity, precision: 14, scale: 3
      t.decimal :unit_cost, precision: 12, scale: 4, null: false
      t.date :effective_on
      t.timestamps
    end
  end
end
