class AddCascadeToLocationProductsLocation < ActiveRecord::Migration[7.0]
  def change
    remove_foreign_key :location_products, :locations
    add_foreign_key :location_products, :locations, on_delete: :cascade
  end
end
