class AddDisabledToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :disabled, :boolean
  end
end
