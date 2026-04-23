class AddLeadTimeToVendors < ActiveRecord::Migration[7.0]
  def change
    add_column :vendors, :lead_time_days, :integer
    add_column :vendors, :contact_name, :string
    add_column :vendors, :email, :string
    add_column :vendors, :phone, :string
  end
end
