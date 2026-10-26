# Order lines for fuel and non-inventory products (diesel, gasoline, Freight - DEF…) were marked
# "production" because only raw materials counted as bought; see Product#produced?.
class SetFuelOrderLinesToBuy < ActiveRecord::Migration[7.2]
  def up
    execute <<~SQL.squish
      UPDATE customer_order_products l SET item_type = 'buy'
      FROM products p JOIN reporting_groups g ON g.name = p.category
      WHERE l.product_id = p.id AND l.item_type = 'production' AND g.item_type IN ('fuel', 'non_inventory')
    SQL
  end

  def down
    # Not reversible: the old rule was wrong.
  end
end
