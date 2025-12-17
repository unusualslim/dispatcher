class CreateProductionOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :production_orders do |t|
      t.string :number
      t.string :status
      t.date :due_date
      t.string :customer_name
      t.string :location_name
      t.integer :priority
      t.text :notes

      t.timestamps
    end
  end
end
