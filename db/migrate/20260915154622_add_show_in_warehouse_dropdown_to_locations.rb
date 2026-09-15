class AddShowInWarehouseDropdownToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :show_in_warehouse_dropdown, :boolean, default: false, null: false

    # Existing origin/terminal locations (category 1) should appear in the dropdown by default
    reversible do |dir|
      dir.up do
        execute <<~SQL
          UPDATE locations SET show_in_warehouse_dropdown = TRUE
          WHERE location_category_id = 1
        SQL
      end
    end
  end
end
