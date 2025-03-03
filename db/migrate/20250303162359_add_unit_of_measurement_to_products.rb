class AddUnitOfMeasurementToProducts < ActiveRecord::Migration[7.0]
  def change
    add_column :products, :unit_of_measurement, :string
  end
end