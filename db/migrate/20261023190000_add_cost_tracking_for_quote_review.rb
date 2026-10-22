class AddCostTrackingForQuoteReview < ActiveRecord::Migration[7.0]
  def up
    # Inventory (weighted average) cost was overwritten on every PDI sync with no
    # history. Record each change from now on so cost movement can be explained.
    create_table :inventory_cost_histories do |t|
      t.string  :product_id, null: false
      t.decimal :amount,          precision: 12, scale: 4
      t.decimal :previous_amount, precision: 12, scale: 4
      t.timestamps
    end
    add_index :inventory_cost_histories, [:product_id, :created_at]

    # When a quote line's cost snapshot was taken, so cost changes since then
    # can be measured against the right date.
    add_column :quote_products, :priced_at, :datetime
    execute <<~SQL
      UPDATE quote_products qp
      SET priced_at = LEAST(qp.updated_at, COALESCE(q.accepted_at, qp.updated_at))
      FROM quotes q
      WHERE q.id = qp.quote_id
    SQL
  end

  def down
    remove_column :quote_products, :priced_at
    drop_table :inventory_cost_histories
  end
end
