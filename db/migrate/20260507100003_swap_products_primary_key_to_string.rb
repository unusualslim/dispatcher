class SwapProductsPrimaryKeyToString < ActiveRecord::Migration[7.0]
  def up
    # Pre-flight: every product must have a part_number
    missing = execute("SELECT COUNT(*) AS n FROM products WHERE part_number IS NULL OR part_number = ''").first["n"].to_i
    raise "#{missing} product(s) have no part_number — run migration 100002 first" if missing > 0

    product_count = execute("SELECT COUNT(*) AS n FROM products").first["n"].to_i

    # ── Step 1: Drop FK constraints ──────────────────────────────────────────
    remove_foreign_key :customer_order_products,   :products
    remove_foreign_key :inventory_transactions,     :products
    remove_foreign_key :location_products,          :products
    remove_foreign_key :product_components,         :products
    remove_foreign_key :product_components,         column: :component_product_id
    remove_foreign_key :production_order_components, :products
    remove_foreign_key :production_orders,           :products
    remove_foreign_key :purchase_orders,             :products

    # ── Step 2: Add new string columns to every FK table ─────────────────────
    add_column :customer_order_products,    :new_product_id, :string
    add_column :inventory_transactions,     :new_product_id, :string
    add_column :location_products,          :new_product_id, :string
    add_column :locations_products,         :new_product_id, :string
    add_column :production_order_components, :new_product_id, :string
    add_column :production_orders,           :new_product_id, :string
    add_column :purchase_orders,             :new_product_id, :string
    add_column :product_components,          :new_product_id, :string
    add_column :product_components,          :new_component_product_id, :string

    # ── Step 3: Populate new columns from products.part_number ───────────────
    [
      :customer_order_products, :inventory_transactions, :location_products,
      :locations_products, :production_order_components, :production_orders,
      :purchase_orders
    ].each do |table|
      execute <<~SQL
        UPDATE #{table} t
           SET new_product_id = p.part_number
          FROM products p
         WHERE p.id = t.product_id
      SQL
    end

    execute <<~SQL
      UPDATE product_components pc
         SET new_product_id           = p1.part_number,
             new_component_product_id = p2.part_number
        FROM products p1, products p2
       WHERE p1.id = pc.product_id
         AND p2.id = pc.component_product_id
    SQL

    # Verify NOT-NULL tables are fully populated (skip tables made nullable in migration 100001)
    {
      inventory_transactions:   :new_product_id,
      location_products:        :new_product_id,
      product_components:       :new_product_id,
      product_components:       :new_component_product_id,
    }.each do |table, col|
      n = execute("SELECT COUNT(*) AS n FROM #{table} WHERE #{col} IS NULL").first["n"].to_i
      raise "#{n} rows in #{table}.#{col} are NULL after populate" if n > 0
    end

    # ── Step 4: Swap products.id to string ───────────────────────────────────
    add_column :products, :new_id, :string
    execute "UPDATE products SET new_id = part_number"

    null_ids = execute("SELECT COUNT(*) AS n FROM products WHERE new_id IS NULL").first["n"].to_i
    raise "#{null_ids} products have NULL new_id" if null_ids > 0

    execute "ALTER TABLE products DROP CONSTRAINT products_pkey"
    execute "ALTER TABLE products DROP COLUMN id"
    execute "DROP SEQUENCE IF EXISTS products_id_seq"
    execute "ALTER TABLE products RENAME COLUMN new_id TO id"
    execute "ALTER TABLE products ADD PRIMARY KEY (id)"

    # Drop part_number — it is now identical to id
    remove_index  :products, :part_number, if_exists: true
    remove_column :products, :part_number

    # ── Step 5: Swap FK columns ───────────────────────────────────────────────
    {
      customer_order_products:    { not_null: false }, # nullable since migration 100001
      inventory_transactions:     { not_null: true },
      location_products:          { not_null: true },
      locations_products:         { not_null: true },
      production_order_components: { not_null: false },
      production_orders:           { not_null: false },
      purchase_orders:             { not_null: false }, # nullable since migration 100001
    }.each do |table, opts|
      remove_index table, name: "index_#{table}_on_product_id", if_exists: true
      execute "ALTER TABLE #{table} DROP COLUMN product_id"
      execute "ALTER TABLE #{table} RENAME COLUMN new_product_id TO product_id"
      execute "ALTER TABLE #{table} ALTER COLUMN product_id SET NOT NULL" if opts[:not_null]
    end

    # product_components has two columns
    remove_index :product_components, name: "index_product_components_on_product_id",           if_exists: true
    remove_index :product_components, name: "index_product_components_on_component_product_id", if_exists: true
    execute "ALTER TABLE product_components DROP COLUMN product_id"
    execute "ALTER TABLE product_components DROP COLUMN component_product_id"
    execute "ALTER TABLE product_components RENAME COLUMN new_product_id           TO product_id"
    execute "ALTER TABLE product_components RENAME COLUMN new_component_product_id TO component_product_id"
    execute "ALTER TABLE product_components ALTER COLUMN product_id           SET NOT NULL"
    execute "ALTER TABLE product_components ALTER COLUMN component_product_id SET NOT NULL"

    # ── Step 6: Re-add FK constraints ────────────────────────────────────────
    add_foreign_key :customer_order_products,    :products
    add_foreign_key :inventory_transactions,     :products
    add_foreign_key :location_products,          :products
    add_foreign_key :product_components,         :products
    add_foreign_key :product_components,         :products, column: :component_product_id
    add_foreign_key :production_order_components, :products
    add_foreign_key :production_orders,           :products
    add_foreign_key :purchase_orders,             :products

    # ── Step 7: Re-add indexes ────────────────────────────────────────────────
    add_index :customer_order_products,    :product_id
    add_index :inventory_transactions,     :product_id
    add_index :location_products,          :product_id
    add_index :locations_products,         :product_id
    add_index :production_order_components, :product_id
    add_index :production_orders,           :product_id
    add_index :purchase_orders,             :product_id
    add_index :product_components,          :product_id
    add_index :product_components,          :component_product_id

    # ── Final verification ────────────────────────────────────────────────────
    new_count = execute("SELECT COUNT(*) AS n FROM products").first["n"].to_i
    raise "Product count changed: was #{product_count}, now #{new_count}" unless new_count == product_count

    say "PK swap complete — #{new_count} products now use string PDI IDs."
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
