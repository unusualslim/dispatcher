class BackfillItemTypeForNonRawMaterialProducts < ActiveRecord::Migration[7.0]
  def up
    execute <<~SQL
      UPDATE customer_order_products
      SET item_type = 'production'
      FROM products
      WHERE customer_order_products.product_id = products.id
        AND products.is_raw_material = false
        AND customer_order_products.item_type = 'buy'
    SQL
  end

  def down
    # Not reversible — we don't know which records were originally 'buy'
  end
end
