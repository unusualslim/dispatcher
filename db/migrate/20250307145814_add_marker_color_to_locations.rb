class AddMarkerColorToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :marker_color, :string
  end
end
