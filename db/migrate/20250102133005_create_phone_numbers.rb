class CreatePhoneNumbers < ActiveRecord::Migration[7.0]
  def change
    create_table :phone_numbers do |t|
      t.references :customer, null: false, foreign_key: true
      t.string :number, null: false

      t.timestamps
    end
  end
end
