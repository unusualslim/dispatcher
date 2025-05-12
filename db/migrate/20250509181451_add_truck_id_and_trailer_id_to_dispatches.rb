class AddTruckIdAndTrailerIdToDispatches < ActiveRecord::Migration[7.0]
  def change
    add_column :dispatches, :truck_id, :integer
    add_column :dispatches, :trailer_id, :integer
  end
end
