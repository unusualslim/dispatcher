class CreateJoinTableLocationsProducts < ActiveRecord::Migration[7.0]
  def change
    create_join_table :locations, :products do |t|
      t.index :location_id
      t.index :product_id
    end
  end
end
