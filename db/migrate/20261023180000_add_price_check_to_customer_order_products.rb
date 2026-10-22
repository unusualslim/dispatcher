class AddPriceCheckToCustomerOrderProducts < ActiveRecord::Migration[7.0]
  def change
    # Price check for imported (PDI) order lines: the price the customer should
    # get (locked quote price or rule price) stored next to PDI's price.
    # price_check: match / lock_mismatch / rule_mismatch / no_price
    add_column :customer_order_products, :expected_price,   :decimal, precision: 12, scale: 4
    add_column :customer_order_products, :price_check,      :string
    add_column :customer_order_products, :price_checked_at, :datetime
    add_index  :customer_order_products, :price_check
  end
end
