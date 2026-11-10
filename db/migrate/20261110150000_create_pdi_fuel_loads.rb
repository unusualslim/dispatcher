# PDI fuel loads (GetFuelLoads): business date, carrier, truck and purchase freight per load, for the freight
# reports' "load business date" basis (it matches PDI's FI Fuel Delivery Report).
class CreatePdiFuelLoads < ActiveRecord::Migration[8.1]
  def change
    create_table :pdi_fuel_loads do |t|
      t.string :load_no, null: false, index: { unique: true }
      t.string :load_reference_no, :vehicle_id, :driver_name
      t.string :carrier_id, index: true
      t.date :business_date, null: false, index: true
      t.date :lift_date
      t.string :order_nos, array: true, default: [], null: false, index: { using: :gin }
      t.jsonb :items, default: [], null: false
      t.timestamps
    end
  end
end
