class ChangeVendorIdToStringPk < ActiveRecord::Migration[7.0]
  def up
    # Step 1: add a temp string column to vendors, populate from pdi_vendor_id
    # (fallback to integer id as string for any vendor without a PDI ID)
    add_column :vendors, :new_id, :string

    execute <<~SQL
      UPDATE vendors
      SET new_id = COALESCE(NULLIF(pdi_vendor_id, ''), id::text)
    SQL

    # Step 2: add temp string FK columns to the three referencing tables
    add_column :dispatches,      :vendor_new_id, :string
    add_column :purchase_orders, :vendor_new_id, :string
    add_column :work_orders,     :vendor_new_id, :string

    execute <<~SQL
      UPDATE dispatches d
      SET vendor_new_id = v.new_id
      FROM vendors v
      WHERE d.vendor_id = v.id
    SQL

    execute <<~SQL
      UPDATE purchase_orders po
      SET vendor_new_id = v.new_id
      FROM vendors v
      WHERE po.vendor_id = v.id
    SQL

    execute <<~SQL
      UPDATE work_orders wo
      SET vendor_new_id = v.new_id
      FROM vendors v
      WHERE wo.vendor_id = v.id
    SQL

    # Step 3: drop FK constraints and old integer vendor_id columns
    remove_foreign_key :dispatches,      :vendors
    remove_foreign_key :purchase_orders, :vendors
    remove_foreign_key :work_orders,     :vendors

    remove_column :dispatches,      :vendor_id
    remove_column :purchase_orders, :vendor_id
    remove_column :work_orders,     :vendor_id

    # Step 4: rename new columns to vendor_id
    rename_column :dispatches,      :vendor_new_id, :vendor_id
    rename_column :purchase_orders, :vendor_new_id, :vendor_id
    rename_column :work_orders,     :vendor_new_id, :vendor_id

    # Step 5: swap the vendors primary key to the string new_id
    execute "ALTER TABLE vendors DROP CONSTRAINT vendors_pkey"
    remove_column :vendors, :id
    rename_column :vendors, :new_id, :id
    execute "ALTER TABLE vendors ADD PRIMARY KEY (id)"

    # Step 6: drop pdi_vendor_id — it's now the primary key
    remove_column :vendors, :pdi_vendor_id

    # Step 7: restore FK constraints using the new string PK
    add_foreign_key :dispatches,      :vendors
    add_foreign_key :purchase_orders, :vendors
    add_foreign_key :work_orders,     :vendors
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
