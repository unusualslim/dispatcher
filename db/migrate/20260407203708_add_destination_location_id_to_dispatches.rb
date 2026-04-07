class AddDestinationLocationIdToDispatches < ActiveRecord::Migration[7.0]
  def change
    add_column :dispatches, :destination_location_id, :integer
  end
end
