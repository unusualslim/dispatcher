# Eight orders entered in the app on Oct 26 picked 10011219 "BULK DEF", which is Blue Bird Body Co.'s product,
# for other customers. Their bulk DEF is 901 (Diesel Exhaust Fluid 32.5%). One-time data fix.
class FixBulkDefOnAppOrders < ActiveRecord::Migration[7.2]
  ORDER_IDS = [8680, 8681, 8683, 8684, 8685, 8686, 8687, 8689].freeze

  def up
    return unless select_value("SELECT 1 FROM products WHERE id = '901'")

    execute <<~SQL.squish
      UPDATE customer_order_products l SET product_id = '901'
      FROM customer_orders o LEFT JOIN customers c ON c.id = o.customer_id
      WHERE l.customer_order_id = o.id AND l.product_id = '10011219' AND o.external_order_no IS NULL
        AND o.id IN (#{ORDER_IDS.join(', ')}) AND coalesce(c.name, '') NOT ILIKE 'Blue Bird%'
    SQL
  end

  def down
    # Data fix; not reversed.
  end
end
