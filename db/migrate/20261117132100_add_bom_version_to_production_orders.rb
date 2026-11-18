# Which BOM version a production order was made with (index built without locking writes).
class AddBomVersionToProductionOrders < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def change
    add_reference :production_orders, :bom_version, index: { algorithm: :concurrently }
    add_foreign_key :production_orders, :bom_versions, on_delete: :nullify, validate: false
  end
end
