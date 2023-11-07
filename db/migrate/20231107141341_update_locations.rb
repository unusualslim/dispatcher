class UpdateLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :dispatch_notes, :text
    add_column :locations, :location_notes, :text
    #Ex:- add_column("admin_users", "username", :string, :limit =>25, :after => "email")
  end
end
