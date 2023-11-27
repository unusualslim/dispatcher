class ChangeDriverNameToId < ActiveRecord::Migration[7.0]
  def change
    remove_column :dispatches, :driver_name
    add_column :dispatches, :driver_id, :integer
    #Ex:- add_column("admin_users", "username", :string, :limit =>25, :after => "email")
    #Ex:- change_column("admin_users", "email", :string, :limit =>25)
  end
end
