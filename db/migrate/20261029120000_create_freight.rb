# Freight on purchases and sales: classes (how much fits on a full load), rate tables, rules that pick a table,
# the charges worked out on each customer order, freight landed into PO costs, and the carrier payables both create.
# rubocop:disable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize -- declarative table definitions
class CreateFreight < ActiveRecord::Migration[7.2]
  def change
    create_freight_classes
    create_freight_tables
    create_freight_table_rates
    create_freight_rules
    create_order_freight_charges
    add_order_freight_inputs
    add_purchase_order_freight
    create_freight_payables
  end

  private

  def create_freight_classes
    create_table :freight_classes do |t|
      t.string :code, null: false
      t.string :name
      t.decimal :full_load_quantity, precision: 14, scale: 3, null: false
      t.string :unit, default: 'gal', null: false
      t.text :notes
      t.timestamps
      t.index :code, unique: true
    end
    add_reference :products, :freight_class, foreign_key: true, type: :bigint
  end

  def create_freight_tables
    create_table :freight_tables do |t|
      t.string :name, null: false
      t.string :lookup_type, null: false, default: 'mileage'
      t.text :notes
      t.timestamps
      t.index :name, unique: true
    end
  end

  def create_freight_table_rates
    create_table :freight_table_rates do |t|
      t.references :freight_table, null: false, foreign_key: true
      t.references :origin_location, foreign_key: { to_table: :locations }
      t.references :destination_location, foreign_key: { to_table: :locations }
      t.decimal :miles_from, precision: 10, scale: 2
      t.decimal :miles_to, precision: 10, scale: 2
      t.decimal :rate, precision: 12, scale: 4, null: false
      t.timestamps
    end
  end

  def create_freight_rules
    create_table :freight_rules do |t|
      t.string :name, null: false
      t.string :side, null: false
      t.string :charge_type, null: false, default: 'freight'
      t.string :basis, null: false
      t.references :freight_table, foreign_key: true
      t.references :origin_location, foreign_key: { to_table: :locations }
      t.references :freight_class, foreign_key: true
      t.string :carrier_id
      t.references :customer, foreign_key: true
      t.decimal :markup_percent, precision: 8, scale: 3
      t.decimal :minimum_amount, precision: 12, scale: 2
      t.date :effective_from, null: false
      t.date :effective_to
      t.boolean :active, default: true, null: false
      t.text :notes
      t.timestamps
      t.index %i[side charge_type active]
      t.index :carrier_id
    end
    add_foreign_key :freight_rules, :vendors, column: :carrier_id
  end

  def create_order_freight_charges
    create_table :order_freight_charges do |t|
      t.references :customer_order, null: false, foreign_key: true
      t.string :side, null: false
      t.string :charge_type, null: false, default: 'freight'
      t.string :description
      t.references :freight_rule, foreign_key: true
      t.references :freight_class, foreign_key: true
      t.string :carrier_id
      t.string :basis
      t.decimal :quantity, precision: 14, scale: 3
      t.decimal :rate, precision: 12, scale: 4
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.boolean :calculated, default: false, null: false
      t.timestamps
    end
    add_foreign_key :order_freight_charges, :vendors, column: :carrier_id
  end

  def add_order_freight_inputs
    change_table :customer_orders, bulk: true do |t|
      t.references :freight_origin_location, foreign_key: { to_table: :locations }
      t.string :freight_carrier_id
      t.decimal :freight_miles, precision: 10, scale: 1
      t.integer :freight_extra_stops, default: 0, null: false
      t.integer :freight_pump_offs, default: 0, null: false
      t.string :freight_presentation, default: 'line', null: false
      t.datetime :freight_calculated_at
    end
  end

  def add_purchase_order_freight
    change_table :purchase_orders, bulk: true do |t|
      t.string :freight_allocation
      t.string :freight_source, default: 'vendor_invoice', null: false
      t.string :freight_vendor_id
      t.string :freight_bol
      t.boolean :freight_accrued, default: false, null: false
    end
  end

  def create_freight_payables
    create_table :freight_payables do |t|
      t.references :source, polymorphic: true, null: false
      t.string :vendor_id, null: false
      t.decimal :accrued_amount, precision: 12, scale: 2
      t.decimal :amount, precision: 12, scale: 2
      t.string :invoice_no
      t.date :invoice_date
      t.string :bol_number
      t.string :status, default: 'accrued', null: false
      t.text :notes
      t.timestamps
      t.index %i[source_type source_id vendor_id], unique: true, name: 'index_freight_payables_on_source_and_vendor'
      t.index :status
    end
    add_foreign_key :freight_payables, :vendors, column: :vendor_id
  end
end
# rubocop:enable Metrics/ClassLength, Metrics/MethodLength, Metrics/AbcSize
