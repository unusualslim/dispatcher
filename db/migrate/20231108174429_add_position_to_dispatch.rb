class AddPositionToDispatch < ActiveRecord::Migration[7.0]
  def change
    add_column :dispatches, :position, :integer
    #Ex:- add_column("admin_users", "username", :string, :limit =>25, :after => "email")
  end
end
