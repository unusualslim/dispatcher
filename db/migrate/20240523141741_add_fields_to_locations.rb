class AddFieldsToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :max_capacity, :integer
    add_column :locations, :uleage_90, :integer
    add_column :locations, :cutoff_percent, :integer
  end
end
