class AddEmploymentTypeToUsers < ActiveRecord::Migration[7.2]
  def change
    # Decides which wage account a worker's /line labor credits (full-time vs temp).
    add_column :users, :employment_type, :string, null: false, default: 'full_time'
  end
end
