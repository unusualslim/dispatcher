class AddPhoneNumberToLocations < ActiveRecord::Migration[7.0]
  def change
    add_column :locations, :phone_number, :string
  end
end
