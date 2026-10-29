# Per-gallon freight rules can charge a short load as a full load of its freight class (e.g. 5,200 gal).
class AddBillFullLoadToFreightRules < ActiveRecord::Migration[7.2]
  def change
    add_column :freight_rules, :bill_full_load, :boolean, default: false, null: false
  end
end
