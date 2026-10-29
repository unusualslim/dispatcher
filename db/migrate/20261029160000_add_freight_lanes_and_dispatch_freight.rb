# Standard miles per origin → destination (lanes), purchase rules priced per dispatch at the farthest stop, and
# order charges that came from a dispatch's carrier freight.
class AddFreightLanesAndDispatchFreight < ActiveRecord::Migration[7.2]
  def change
    create_lanes
    add_column :freight_rules, :calculation, :string, default: 'order', null: false
    add_reference :order_freight_charges, :dispatch, foreign_key: true, type: :bigint
    add_column :dispatches, :freight_calculated_at, :datetime
  end

  private

  def create_lanes
    create_table :freight_lanes do |t|
      t.references :origin_location, null: false, foreign_key: { to_table: :locations }
      t.references :destination_location, null: false, foreign_key: { to_table: :locations }
      t.decimal :standard_miles, precision: 10, scale: 1, null: false
      t.text :notes
      t.timestamps
      t.index %i[origin_location_id destination_location_id], unique: true, name: 'index_freight_lanes_on_route'
    end
  end
end
