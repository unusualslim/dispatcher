class AddSheetFieldsToProductionOrders < ActiveRecord::Migration[7.0]
  def change
    add_column :production_orders, :item, :string
    add_column :production_orders, :batch_number, :string
    add_column :production_orders, :qty_to_make, :decimal, precision: 12, scale: 3

    add_column :production_orders, :production_notes, :text
    add_column :production_orders, :date_started, :date
    add_column :production_orders, :date_completed, :date
    add_column :production_orders, :total_qty_produced, :decimal, precision: 12, scale: 3

    add_column :production_orders, :filled_by, :string
    add_column :production_orders, :approved_by, :string
  end
end