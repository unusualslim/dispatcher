# PDI's fuel products and their reporting groups (from PDI's fuel product list, Oct 2026), so the
# FI Inventory sync can match them and fuel groups are typed as fuel.
class AddFuelReportingGroups < ActiveRecord::Migration[7.2]
  GROUPS = %w[DEF-Fuel GASOLINE DIESEL PROPANE].freeze

  # [id, description, reporting group, raw material for DEF production]
  PRODUCTS = [
    ['022BBCJ00DEF187', 'PRODEF Bulk', 'DEF-Fuel', false],
    ['10011219', '10011219 BULK DEF', 'DEF-Fuel', false],
    ['101', '87 Regular w/10% Ethanol', 'GASOLINE', false],
    ['102', '87 Regular Conventional', 'GASOLINE', false],
    ['301', '93 premium w/ 10% Ethanol', 'GASOLINE', false],
    ['401', 'Ultra Low Sulfur #2 Diesel', 'DIESEL', false],
    ['501', 'Ultra Low Sulfur#2 Dyed Diesel', 'DIESEL', false],
    ['801', 'Propane-Cylinders', 'PROPANE', false],
    ['901', 'Diesel Exhaust Fluid 32.5%', 'DEF-Fuel', false],
    ['901B', 'Blended 32.5%', 'DEF-Fuel', false],
    ['CC36057', 'Cummins DEF Bulk', 'DEF-Fuel', false],
    ['DIWATER', 'Deionized Water', 'DEF-Fuel', true],
    ['FRTDEF', 'Freight - DEF', 'DEF-Fuel', false],
    ['MF10011219', 'Mansfield DEF', 'DEF-Fuel', false],
    ['UFV1', 'Urea (Granular) Short Ton', 'DEF-Fuel', true],
    ['ULQ50', 'Urea Liquor 50%', 'DEF-Fuel', true]
  ].freeze

  def up
    upsert_groups
    upsert_products
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end

  private

  def upsert_groups
    GROUPS.each do |name|
      execute <<~SQL.squish
        INSERT INTO reporting_groups (name, item_type, created_at, updated_at)
        VALUES (#{quote(name)}, 'fuel', NOW(), NOW())
        ON CONFLICT (name) DO UPDATE SET item_type = 'fuel', updated_at = NOW()
      SQL
    end
  end

  # Existing products keep their name and settings; only the reporting group (category) is set.
  def upsert_products
    PRODUCTS.each do |id, name, group, raw|
      execute <<~SQL.squish
        INSERT INTO products (id, name, category, is_raw_material, created_at, updated_at)
        VALUES (#{quote(id)}, #{quote(name)}, #{quote(group)}, #{raw}, NOW(), NOW())
        ON CONFLICT (id) DO UPDATE SET category = EXCLUDED.category, updated_at = NOW()
      SQL
    end
  end

  def quote(value)
    connection.quote(value)
  end
end
