# PDI's freight in detail (rules behind each fuel line's freight: base rate, FPLFSC, TAFSC…) from the nightly
# PDI SQL export, for the freight reports. See PdiFreightComponent.
class CreatePdiFreightComponents < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :pdi_freight_components do |t|
      t.string :source, :component_key, :line_key, :charge, null: false
      t.string :load_no, :load_reference_no, :bol, :product, :method
      t.string :order_no, index: true
      t.date :business_date
      t.integer :rule_type
      t.boolean :purchase, :sale, null: false, default: false
      t.decimal :line_freight, :amount, precision: 14, scale: 2
      t.decimal :basis, precision: 14, scale: 4
      t.decimal :rate, precision: 14, scale: 6
      t.timestamps
      t.index %i[source component_key], unique: true
      t.index %i[source line_key]
    end
  end
end
