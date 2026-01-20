class CreateProductComponents < ActiveRecord::Migration[7.0]
  def change
    create_table :product_components do |t|
      t.references :product, null: false, foreign_key: true

      t.references :component_product,
                   null: false,
                   foreign_key: { to_table: :products }

      t.decimal :quantity_per_unit, precision: 12, scale: 3
      t.string :uom

      t.timestamps
    end
  end
end