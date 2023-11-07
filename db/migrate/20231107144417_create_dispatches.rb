class CreateDispatches < ActiveRecord::Migration[7.0]
  def change
    create_table :dispatches do |t|
      t.string :driver_name
      t.string :origin
      t.text :info
      t.date :dispatch_date
      t.string :status
      t.text :notes

      t.timestamps
    end
  end
end
