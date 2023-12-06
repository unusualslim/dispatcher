class AddConsentToTextToUsers < ActiveRecord::Migration[7.0]
  def change
    add_column :users, :consent_to_text, :boolean
  end
end
