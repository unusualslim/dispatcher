class CreateCustomerLocations < ActiveRecord::Migration[7.0]
  def change
    create_table :customer_locations do |t|
      t.references :customer, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true

      t.timestamps
    end
  end
end
