# The customer's own part number for an item, printed beside FPS's item number on quotes and bills of lading.
class CreateCustomerItemNumbers < ActiveRecord::Migration[8.1]
  def change
    create_table :customer_item_numbers do |t|
      t.references :customer, null: false, foreign_key: { on_delete: :cascade }
      t.references :product, type: :string, null: false, foreign_key: { on_delete: :cascade }
      t.string :part_number, null: false
      t.string :description
      t.timestamps
      t.index %i[customer_id product_id], unique: true
    end
  end
end
