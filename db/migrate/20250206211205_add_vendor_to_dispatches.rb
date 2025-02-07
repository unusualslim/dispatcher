class AddVendorToDispatches < ActiveRecord::Migration[7.0]
  def change
    add_reference :dispatches, :vendor, null: true, foreign_key: true
  end
end
