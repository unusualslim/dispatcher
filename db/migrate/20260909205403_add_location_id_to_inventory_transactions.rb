class AddLocationIdToInventoryTransactions < ActiveRecord::Migration[7.0]
  def change
    add_column :inventory_transactions, :location_id, :bigint
  end
end
