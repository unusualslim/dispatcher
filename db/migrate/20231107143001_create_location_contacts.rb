class CreateLocationContacts < ActiveRecord::Migration[7.0]
  def change
    create_table :location_contacts do |t|
      t.string :name
      t.string :email
      t.string :phone
      t.references :location, null: false, foreign_key: true

      t.timestamps
    end
  end
end
