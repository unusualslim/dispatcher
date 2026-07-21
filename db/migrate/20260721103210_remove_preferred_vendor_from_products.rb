class RemovePreferredVendorFromProducts < ActiveRecord::Migration[7.0]
  def change
    remove_reference :products, :preferred_vendor, type: :string, foreign_key: { to_table: :vendors }, index: true
  end
end
