class AddPriceLockingToQuotes < ActiveRecord::Migration[7.0]
  def change
    # Quote validity window. Only quotes with locks_pricing = true lock prices when
    # accepted; existing quotes default to false and stay historical records.
    add_column :quotes, :valid_from,     :date
    add_column :quotes, :locks_pricing,  :boolean, default: false, null: false
    add_column :quotes, :accepted_at,    :datetime
    add_reference :quotes, :accepted_by, foreign_key: { to_table: :users }

    # Snapshot of how each quoted price was reached.
    add_reference :quote_products, :pricing_rule, foreign_key: { on_delete: :nullify }
    add_column :quote_products, :pricing_basis,  :string
    add_column :quote_products, :pricing_method, :string
    add_column :quote_products, :rule_value,     :decimal, precision: 12, scale: 4
    add_column :quote_products, :basis_cost,     :decimal, precision: 12, scale: 4
    add_column :quote_products, :price_overridden, :boolean, default: false, null: false
    # Set when a newer accepted quote takes over this product for the customer;
    # the lock ends the day before this date.
    add_column :quote_products, :superseded_on, :date
    add_index  :quote_products, :product_id

    # Audit trail: what priced each order line.
    add_reference :customer_order_products, :quote_product, foreign_key: { on_delete: :nullify }
    add_reference :customer_order_products, :pricing_rule,  foreign_key: { on_delete: :nullify }
  end
end
