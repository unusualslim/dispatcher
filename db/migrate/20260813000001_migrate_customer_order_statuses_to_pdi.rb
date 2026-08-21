class MigrateCustomerOrderStatusesToPdi < ActiveRecord::Migration[7.0]
  def up
    # Convert old app-specific statuses to PDI equivalents
    execute <<~SQL
      UPDATE customer_orders SET order_status = 'Open Order'       WHERE order_status = 'New';
      UPDATE customer_orders SET order_status = 'Billed'           WHERE order_status = 'Complete';
      UPDATE customer_orders SET order_status = 'Expired'          WHERE order_status = 'On Hold';
      UPDATE customer_orders SET order_status = 'Cancelled as Order' WHERE order_status = 'Deleted';
    SQL
  end

  def down
    execute <<~SQL
      UPDATE customer_orders SET order_status = 'New'      WHERE order_status = 'Open Order';
      UPDATE customer_orders SET order_status = 'Complete'  WHERE order_status = 'Billed';
      UPDATE customer_orders SET order_status = 'On Hold'   WHERE order_status = 'Expired';
      UPDATE customer_orders SET order_status = 'Deleted'   WHERE order_status = 'Cancelled as Order';
    SQL
  end
end
