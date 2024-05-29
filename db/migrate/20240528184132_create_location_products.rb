class CreateLocationProducts < ActiveRecord::Migration[7.0]
  def change
    create_table :location_products do |t|
      t.references :location, null: false, foreign_key: true
      t.references :product, null: false, foreign_key: true
      t.integer :max_capacity
      t.integer :uleage_90
      t.integer :cutoff

      t.timestamps
    end
  end
end
