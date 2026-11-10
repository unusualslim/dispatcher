# Fills the new truck/freight columns from the order feeds already saved on SyncLogs (Sep–Nov 2026).
class BackfillTruckFreight < ActiveRecord::Migration[8.1]
  def up
    CustomerOrder.reset_column_information
    count = PdiOrders::TruckFreightBackfill.new.run
    say "Truck/freight filled on #{count} orders"
  end

  def down; end
end
