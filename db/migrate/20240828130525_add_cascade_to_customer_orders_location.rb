class AddCascadeToCustomerOrdersLocation < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :customer_orders, :locations
    add_foreign_key :customer_orders, :locations, on_delete: :cascade
  end
end
