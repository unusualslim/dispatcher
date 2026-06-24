class AddFileBinaryToSyncLogs < ActiveRecord::Migration[7.0]
  def change
    add_column :sync_logs, :file_binary, :boolean
  end
end
