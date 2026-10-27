# rubocop:disable Metrics/MethodLength, Metrics/AbcSize -- table definitions read best whole
# Costed inventory movements: each reporting group picks weighted average, standard or FIFO; every
# movement records its cost, and each location keeps an inventory value (FIFO also keeps cost layers).
class AddInventoryCosting < ActiveRecord::Migration[7.2]
  def change
    add_column :reporting_groups, :costing_method, :string, null: false, default: 'weighted_average'

    change_table :inventory_transactions, bulk: true do |t|
      t.string :movement_type
      t.date :occurred_on
      t.decimal :unit_cost, precision: 14, scale: 6
      t.decimal :total_cost, precision: 16, scale: 4
      t.decimal :variance_amount, precision: 16, scale: 4
      t.decimal :balance_quantity, precision: 14, scale: 3
      t.decimal :balance_value, precision: 16, scale: 4
      t.index :movement_type
      t.index %i[product_id location_id occurred_on]
    end

    add_column :location_products, :inventory_value, :decimal, precision: 16, scale: 4, null: false, default: 0

    # What actually shipped (PDI invoiced / picked / lifted quantity); sales take this out of stock.
    add_column :customer_order_products, :shipped_quantity, :decimal, precision: 14, scale: 3

    create_table :inventory_cost_layers do |t|
      t.string :product_id, null: false
      t.references :location, null: false, foreign_key: true
      t.references :inventory_transaction, foreign_key: true
      t.date :received_on, null: false
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.decimal :remaining_quantity, precision: 14, scale: 3, null: false
      t.decimal :unit_cost, precision: 14, scale: 6, null: false
      t.timestamps
      t.index %i[product_id location_id received_on]
    end

    # Which FIFO layers an issue drew from, so a reversal can put the quantity back.
    create_table :inventory_layer_draws do |t|
      t.references :inventory_transaction, null: false, foreign_key: true
      t.references :inventory_cost_layer, null: false, foreign_key: true
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.decimal :unit_cost, precision: 14, scale: 6, null: false
      t.timestamps
    end
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
