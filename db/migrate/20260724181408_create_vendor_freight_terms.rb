class CreateVendorFreightTerms < ActiveRecord::Migration[7.0]
  def change
    create_table :vendor_freight_terms do |t|
      t.string :vendor_id, null: false
      t.string :freight_term, null: false
      t.timestamps
    end
    add_index :vendor_freight_terms, [:vendor_id, :freight_term], unique: true
  end
end
