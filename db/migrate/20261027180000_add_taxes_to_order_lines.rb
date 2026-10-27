# PDI's estimated tax per unit on each order line, and whether the unit price already includes it
# (UnitPriceIncludesTaxes), so sales can be split into product and taxes. Lines from before this are nil.
class AddTaxesToOrderLines < ActiveRecord::Migration[7.2]
  def change
    change_table :customer_order_products, bulk: true do |t|
      t.decimal :tax_per_unit, precision: 14, scale: 7
      t.boolean :price_includes_taxes # rubocop:disable Rails/ThreeStateBooleanColumn -- nil = PDI didn't say
    end
  end
end
