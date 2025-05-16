class AddWorkableToWorkOrders < ActiveRecord::Migration[7.0]
  def change
    add_reference :work_orders, :workable, polymorphic: true, null: false
    remove_column :work_orders, :location_id, :bigint
    remove_column :work_orders, :asset_id, :bigint
  end
end
