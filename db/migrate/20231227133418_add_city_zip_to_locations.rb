class AddCityZipToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :zip, :string
    rename_column :locations, :name, :city
    #Ex:- change_column("admin_users", "email", :string, :limit =>25)
    #Ex:- add_column("admin_users", "username", :string, :limit =>25, :after => "email")
  end
end
