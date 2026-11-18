# Files kept for a product (the SDS first). A record of its own because Active Storage keys attachments by a
# numeric id and product ids are text.
class CreateProductDocuments < ActiveRecord::Migration[8.1]
  def change
    create_table :product_documents do |t|
      t.references :product, type: :string, null: false, foreign_key: { on_delete: :cascade }
      t.string :kind, null: false, default: 'sds'
      t.timestamps
      t.index %i[product_id kind], unique: true
    end
  end
end
