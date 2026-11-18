# Saved versions of a product's bill of materials (components and cost lines), so former versions can be seen and
# each production order records the version it was made with.
class CreateBomVersions < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :bom_versions do |t|
      t.references :product, type: :string, null: false, foreign_key: { on_delete: :cascade }
      t.integer :number, null: false
      t.date :effective_on, null: false
      t.jsonb :components, null: false, default: []
      t.jsonb :cost_lines, null: false, default: []
      t.string :source
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
      t.index %i[product_id number], unique: true
    end
  end
end
