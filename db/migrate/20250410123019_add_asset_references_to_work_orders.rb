class AddAssetReferencesToWorkOrders < ActiveRecord::Migration[7.0]
  def change
    add_reference :work_orders, :asset, null: false, foreign_key: true
  end
end
