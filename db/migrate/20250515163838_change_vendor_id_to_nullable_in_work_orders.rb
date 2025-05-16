class ChangeVendorIdToNullableInWorkOrders < ActiveRecord::Migration[7.0]
  def change
    change_column_null :work_orders, :vendor_id, true
  end
end
