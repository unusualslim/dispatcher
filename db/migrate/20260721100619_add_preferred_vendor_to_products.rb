class AddPreferredVendorToProducts < ActiveRecord::Migration[7.0]
  def change
    add_reference :products, :preferred_vendor, type: :string, foreign_key: { to_table: :vendors }, null: true, index: true
  end
end
