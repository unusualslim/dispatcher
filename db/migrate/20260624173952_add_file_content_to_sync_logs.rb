class AddFileContentToSyncLogs < ActiveRecord::Migration[7.0]
  def change
    add_column :sync_logs, :file_content, :text
  end
end
