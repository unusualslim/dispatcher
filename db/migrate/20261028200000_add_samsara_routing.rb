# Links for pushing dispatches to Samsara as routes: drivers ↔ Samsara drivers (plus the yard their routes start and
# end at), locations ↔ Samsara addresses, dispatches ↔ the route created from them.
class AddSamsaraRouting < ActiveRecord::Migration[7.2]
  def change
    add_column :users, :samsara_driver_id, :string
    add_reference :users, :home_location, foreign_key: { to_table: :locations }
    add_column :locations, :samsara_address_id, :string
    add_index :locations, :samsara_address_id
    change_table :dispatches, bulk: true do |t|
      t.string :samsara_route_id
      t.datetime :samsara_sent_at
    end
  end
end
