# Lead times for time-phased MRP (Mrp::Plan). Blank = the app-wide default (AppSetting mrp_*).
class AddMrpLeadTimes < ActiveRecord::Migration[7.2]
  def change
    change_table :products, bulk: true do |t|
      t.integer :lead_time_days    # purchase lead time; overrides the primary vendor's
      t.integer :production_days   # start of production → finished goods
    end
    add_column :customers, :lead_time_days, :integer # usual order-to-delivery time
  end
end
