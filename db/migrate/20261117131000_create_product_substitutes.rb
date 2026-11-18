# Approved substitutes for an item (used in its place in production when it's short), in order of preference.
class CreateProductSubstitutes < ActiveRecord::Migration[8.1]
  def change
    create_table :product_substitutes do |t|
      t.references :product, type: :string, null: false, foreign_key: { on_delete: :cascade }
      t.references :substitute, type: :string, null: false, foreign_key: { to_table: :products, on_delete: :cascade }
      t.integer :priority, null: false, default: 1
      t.decimal :ratio, precision: 12, scale: 4, null: false, default: 1
      t.text :notes
      t.timestamps
      t.index %i[product_id substitute_id], unique: true
    end
  end
end
