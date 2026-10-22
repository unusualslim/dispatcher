class BackfillTemporaryStandardCosts < ActiveRecord::Migration[7.0]
  NOTE = 'Temporary: inventory cost + 1% (auto-filled)'.freeze

  # Gives every product without a standard cost a temporary one of inventory
  # (weighted average) cost + 1%, recorded in standard cost history with a note
  # so it's easy to find and replace. Products that already have a standard
  # cost (column set or any history entry) or have no inventory cost are skipped.
  def up
    add_column :standard_cost_histories, :notes, :string

    execute <<~SQL
      CREATE TEMP TABLE temp_standard_costs ON COMMIT DROP AS
      SELECT p.id AS product_id, ROUND(p.cost_per_unit * 1.01, 4) AS amount
      FROM products p
      WHERE p.standard_cost IS NULL
        AND p.cost_per_unit > 0
        AND NOT EXISTS (SELECT 1 FROM standard_cost_histories h WHERE h.product_id = p.id)
    SQL

    execute <<~SQL
      INSERT INTO standard_cost_histories (product_id, amount, effective_date, notes, created_at, updated_at)
      SELECT product_id, amount, CURRENT_DATE, #{connection.quote(NOTE)}, NOW(), NOW()
      FROM temp_standard_costs
    SQL

    updated = exec_update(<<~SQL)
      UPDATE products p
      SET standard_cost = t.amount, updated_at = NOW()
      FROM temp_standard_costs t
      WHERE p.id = t.product_id
    SQL

    say "Set a temporary standard cost on #{updated} product(s)"
  end

  def down
    # Only products whose sole history entry is the auto-filled one get their
    # column cleared; anything edited since keeps its standard cost.
    execute <<~SQL
      UPDATE products p
      SET standard_cost = NULL
      WHERE EXISTS (SELECT 1 FROM standard_cost_histories h WHERE h.product_id = p.id AND h.notes = #{connection.quote(NOTE)})
        AND NOT EXISTS (SELECT 1 FROM standard_cost_histories h WHERE h.product_id = p.id AND h.notes IS DISTINCT FROM #{connection.quote(NOTE)})
    SQL
    execute "DELETE FROM standard_cost_histories WHERE notes = #{connection.quote(NOTE)}"
    remove_column :standard_cost_histories, :notes
  end
end
