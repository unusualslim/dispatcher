class AddLastTriggeredAtToAutomatedProcessConfigs < ActiveRecord::Migration[7.0]
  def change
    add_column :automated_process_configs, :last_triggered_at, :datetime
  end
end
