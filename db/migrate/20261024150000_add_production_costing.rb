class AddProductionCosting < ActiveRecord::Migration[7.2]
  def change
    create_reporting_groups
    create_product_cost_lines

    # The single "Repacking Fee" PDI capitalizes per unit; the app's GL export clears it.
    add_column :products, :pdi_repack_fee, :decimal, precision: 12, scale: 4

    create_table :app_settings do |t|
      t.string :key, null: false, index: { unique: true }
      t.string :value
      t.timestamps
    end
  end

  private

  # Reporting groups decide where costs post (Major-Sub; the site comes from the location).
  # item_type mirrors PDI: fuel and warehouse groups are PDI's product categories (linked to
  # products by name); non_inventory groups hold BOM cost lines. A labor group is absorbed at
  # actual /line hours and posts temp hours to temp_gl_account.
  def create_reporting_groups
    create_table :reporting_groups do |t|
      t.string  :name, null: false, index: { unique: true }
      t.string  :item_type, null: false
      t.string  :gl_account
      t.string  :temp_gl_account
      t.boolean :labor, null: false, default: false
      t.integer :position
      t.timestamps
    end
    reversible { |dir| dir.up { seed_reporting_groups } }
  end

  def seed_reporting_groups
    execute <<~SQL.squish
      INSERT INTO reporting_groups (name, item_type, labor, position, created_at, updated_at) VALUES
        ('Consumables', 'non_inventory', false, 1, NOW(), NOW()),
        ('Labor', 'non_inventory', true, 2, NOW(), NOW()),
        ('Overhead', 'non_inventory', false, 3, NOW(), NOW())
    SQL
    seed_pdi_category_groups
  end

  # Existing product categories become fuel (any tank-tracked product) or warehouse groups.
  def seed_pdi_category_groups
    execute <<~SQL.squish
      INSERT INTO reporting_groups (name, item_type, created_at, updated_at)
      SELECT category, CASE WHEN BOOL_OR(COALESCE(pdi_tank_id, '') <> '') THEN 'fuel' ELSE 'warehouse' END, NOW(), NOW()
      FROM products WHERE COALESCE(category, '') <> '' GROUP BY category
      ON CONFLICT (name) DO NOTHING
    SQL
  end

  # Non-inventory costs absorbed into a finished good (pallets, film, labor, overhead).
  # Cost per unit = quantity × unit_cost ÷ per_quantity.
  def create_product_cost_lines
    create_table :product_cost_lines do |t|
      t.string     :product_id, null: false, index: true
      t.references :reporting_group, null: false, foreign_key: true
      t.string     :description, null: false
      t.decimal    :quantity, precision: 12, scale: 4, null: false, default: 1
      t.decimal    :unit_cost, precision: 12, scale: 4
      t.decimal    :per_quantity, precision: 12, scale: 4, null: false, default: 1
      t.integer    :position
      t.timestamps
    end
  end
end
