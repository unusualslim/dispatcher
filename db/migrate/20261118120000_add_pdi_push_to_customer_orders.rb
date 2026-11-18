# Send to PDI (fuel orders): the customer's PO number and a delivery time on the order, the push state, and which
# customers require a PO number.
class AddPdiPushToCustomerOrders < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/MethodLength
    safety_assured do # nullable columns only: no rewrite, no default backfill
      change_table :customer_orders, bulk: true do |t|
        t.string :customer_po_number, limit: 20
        t.time :delivery_time
        t.string :pdi_push_status
        t.datetime :pdi_pushed_at
        t.bigint :pdi_pushed_by_id
        t.string :pdi_request_id
        t.text :pdi_push_response
        t.text :pdi_push_error
      end
    end
    add_column :customers, :po_required, :boolean, null: false, default: false
  end
end
