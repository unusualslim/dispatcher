# Per-area access levels for staff users, e.g. { "sales" => "edit", "accounting" => "approve" }.
class AddPermissionsToUsers < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :permissions, :jsonb, null: false, default: {}
  end
end
