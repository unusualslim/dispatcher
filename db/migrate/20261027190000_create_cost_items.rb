# rubocop:disable Metrics/MethodLength -- table definitions read best whole
# Catalog of non-inventory costs (pallets, film, tape, labels, labor, overhead) with their current price.
# A product cost line can point at one so a price change flows to every finished good that uses it.
class CreateCostItems < ActiveRecord::Migration[7.2]
  def change
    create_table :cost_items do |t|
      t.string :name, null: false, index: { unique: true }
      t.references :reporting_group, null: false, foreign_key: true
      t.decimal :unit_cost, precision: 12, scale: 5, null: false
      t.string :unit
      t.string :vendor
      t.date :effective_date
      t.text :notes
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    add_reference :product_cost_lines, :cost_item, foreign_key: true
  end
end
# rubocop:enable Metrics/MethodLength
