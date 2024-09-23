class AddDetailsToCustomers < ActiveRecord::Migration[7.0]
  def change
    add_column :customers, :email, :string
    add_column :customers, :phone, :string
    add_column :customers, :preferred_contact_method, :string
  end
end
