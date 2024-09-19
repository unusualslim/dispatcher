class CreateCustomers < ActiveRecord::Migration[7.0]
  def change
    unless table_exists?(:customers)
      create_table :customers do |t|
        t.string :name
        t.timestamps
      end
    end
  end
end
