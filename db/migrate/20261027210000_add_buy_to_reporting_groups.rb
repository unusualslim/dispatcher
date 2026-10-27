# Warehouse groups whose products are bought finished, never made here (HYDRAULICS): their order lines are "buy",
# not production. Existing HYDRAULICS order lines are switched to buy.
class AddBuyToReportingGroups < ActiveRecord::Migration[7.2]
  def up
    add_column :reporting_groups, :buy, :boolean, default: false, null: false
    execute "UPDATE reporting_groups SET buy = TRUE WHERE UPPER(name) = 'HYDRAULICS'"
    execute <<~SQL.squish
      UPDATE customer_order_products SET item_type = 'buy'
      FROM products
      JOIN reporting_groups ON reporting_groups.name = products.category AND reporting_groups.buy
      WHERE products.id = customer_order_products.product_id AND customer_order_products.item_type = 'production'
    SQL
  end

  def down
    remove_column :reporting_groups, :buy
  end
end
