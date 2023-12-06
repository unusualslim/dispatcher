class AddNotesToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :notes, :text
  end
end
