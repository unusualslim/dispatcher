class AddPdiTankIdToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :pdi_tank_id, :string
  end
end
