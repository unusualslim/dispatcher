class AddDefaultToPreferredContactMethodInCustomers < ActiveRecord::Migration[7.0]
  def change
    change_column_default :customers, :preferred_contact_method, 'no preference'
  end
end
