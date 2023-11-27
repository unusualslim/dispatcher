class AddOptInsToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :email_opt_in, :boolean
    add_column :users, :sms_opt_in, :boolean
  end
end
