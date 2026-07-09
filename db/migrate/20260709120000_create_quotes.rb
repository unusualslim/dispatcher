class CreateQuotes < ActiveRecord::Migration[7.0]
  def change
    create_table :quotes do |t|
      t.string  :quote_number, null: false
      t.references :customer, null: false, foreign_key: true
      t.references :location, foreign_key: true
      t.string  :status, default: 'draft', null: false
      t.date    :expiry_date
      t.text    :notes
      t.datetime :sent_at
      t.references :customer_order, foreign_key: true
      t.timestamps
    end

    add_index :quotes, :quote_number, unique: true

    create_table :quote_products do |t|
      t.references :quote, null: false, foreign_key: true
      t.string  :product_id
      t.string  :product_name
      t.decimal :quantity, precision: 14, scale: 3
      t.decimal :price, precision: 12, scale: 4
      t.timestamps
    end

    add_foreign_key :quote_products, :products, column: :product_id
  end
end
