class RemovingTextFromLocations < ActiveRecord::Migration[7.0]
  def change
    remove_column :locations, :location_notes
    remove_column :locations, :dispatch_notes
  end
end
