class AddNeedsUpdatingToDispatches < ActiveRecord::Migration[7.0]
  def change
    add_column :dispatches, :needs_updating, :boolean
    remove_column :users, :consent_to_text
  end
end
