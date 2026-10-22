class BackfillCustomerLocationsFromOrders < ActiveRecord::Migration[7.0]
  # Links each customer to every location they've had an order for, so the
  # order form can list the customer's locations first. New orders keep this
  # current via CustomerOrder#link_customer_location.
  def up
    # Drop duplicate links (keep the oldest) so the pair can be unique.
    execute <<~SQL
      DELETE FROM customer_locations a
      USING customer_locations b
      WHERE a.customer_id = b.customer_id
        AND a.location_id = b.location_id
        AND a.id > b.id
    SQL

    add_index :customer_locations, [:customer_id, :location_id], unique: true

    execute <<~SQL
      INSERT INTO customer_locations (customer_id, location_id, created_at, updated_at)
      SELECT DISTINCT o.customer_id, o.location_id, NOW(), NOW()
      FROM customer_orders o
      JOIN customers c ON c.id = o.customer_id
      JOIN locations l ON l.id = o.location_id
      WHERE o.customer_id IS NOT NULL AND o.location_id IS NOT NULL
      ON CONFLICT (customer_id, location_id) DO NOTHING
    SQL
  end

  def down
    # Backfilled links can't be told apart from ones added by hand, so they stay.
    remove_index :customer_locations, [:customer_id, :location_id]
  end
end
