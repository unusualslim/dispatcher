# Admins can correct /line clock times; record who changed them since they drive labor costing.
class AddEditTrackingToJobs < ActiveRecord::Migration[7.2]
  def change
    add_reference :jobs, :edited_by, foreign_key: { to_table: :users }
    add_column :jobs, :edited_at, :datetime
  end
end
