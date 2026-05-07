class CleanupProductsBeforePkSwap < ActiveRecord::Migration[7.0]
  # Merge source_id into target_id, then delete source
  MERGES = { 34 => 16 }.freeze

  # Products with no PDI match — remove them but preserve references in historical tables
  TRASH_IDS = [22, 23, 26, 29, 32, 35, 36, 42, 46, 47].freeze

  def up
    ids = TRASH_IDS.join(", ")

    # ── Step 1: Add product_name to historical tables ─────────────────────────
    # Denormalize the name now so rows that lose their FK still show what the
    # product was. We populate for ALL rows, not just the trashed ones — the
    # column is useful going forward too.
    add_column :customer_order_products, :product_name, :string
    add_column :purchase_orders,         :product_name, :string

    execute <<~SQL
      UPDATE customer_order_products cop
         SET product_name = p.name
        FROM products p
       WHERE p.id = cop.product_id
    SQL
    execute <<~SQL
      UPDATE purchase_orders po
         SET product_name = p.name
        FROM products p
       WHERE p.id = po.product_id
    SQL

    # Make product_id nullable in these two tables so we can orphan the rows
    # instead of deleting them when a product is trashed.
    change_column_null :customer_order_products, :product_id, true
    change_column_null :purchase_orders,         :product_id, true

    # ── Step 2: Merge duplicate products into their canonical product ─────────
    MERGES.each do |source_id, target_id|
      %w[customer_order_products inventory_transactions location_products
         locations_products production_order_components production_orders
         purchase_orders].each do |table|
        execute "UPDATE #{table} SET product_id = #{target_id} WHERE product_id = #{source_id}"
      end
      execute "UPDATE product_components SET product_id            = #{target_id} WHERE product_id            = #{source_id}"
      execute "UPDATE product_components SET component_product_id  = #{target_id} WHERE component_product_id  = #{source_id}"
      execute "DELETE FROM products WHERE id = #{source_id}"
    end

    # ── Step 3: Handle trashed products ──────────────────────────────────────
    # Historical tables: null out the FK — product_name already set above
    execute "UPDATE customer_order_products SET product_id = NULL WHERE product_id IN (#{ids})"
    execute "UPDATE purchase_orders         SET product_id = NULL WHERE product_id IN (#{ids})"

    # Audit / config tables: delete the rows outright
    execute "DELETE FROM inventory_transactions WHERE product_id IN (#{ids})"
    execute "DELETE FROM location_products       WHERE product_id IN (#{ids})"
    execute "DELETE FROM locations_products      WHERE product_id IN (#{ids})"
    execute "DELETE FROM product_components WHERE product_id IN (#{ids}) OR component_product_id IN (#{ids})"

    # These already allow NULL product_id
    execute "UPDATE production_order_components SET product_id = NULL WHERE product_id IN (#{ids})"
    execute "UPDATE production_orders           SET product_id = NULL WHERE product_id IN (#{ids})"

    # ── Step 4: Delete the trashed products ───────────────────────────────────
    execute "DELETE FROM products WHERE id IN (#{ids})"

    remaining = execute("SELECT COUNT(*) AS n FROM products").first["n"].to_i
    say "Cleanup complete — #{remaining} products remain."
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
