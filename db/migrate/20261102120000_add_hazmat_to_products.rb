# DOT hazardous-materials data for bills of lading. PDI's master data sends the flag and notes for warehouse
# products; fuel products (gasoline, diesel, propane) are entered in the app.
class AddHazmatToProducts < ActiveRecord::Migration[7.2]
  def change
    change_table :products, bulk: true do |t|
      t.boolean :hazmat, default: false, null: false
      t.text :hazmat_description
      t.string :hazmat_emergency_phone
    end
  end
end
