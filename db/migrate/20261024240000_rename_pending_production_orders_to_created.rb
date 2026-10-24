# "Pending" production orders are now "created": planned, nothing done yet.
class RenamePendingProductionOrdersToCreated < ActiveRecord::Migration[7.2]
  def up
    execute "UPDATE production_orders SET status = 'created' WHERE status = 'pending'"
  end

  def down
    execute "UPDATE production_orders SET status = 'pending' WHERE status = 'created'"
  end
end
