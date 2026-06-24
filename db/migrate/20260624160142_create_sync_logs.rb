class CreateSyncLogs < ActiveRecord::Migration[7.0]
  def change
    create_table :sync_logs do |t|
      t.string :process_name
      t.string :status
      t.string :file_name
      t.datetime :started_at
      t.datetime :completed_at
      t.integer :records_created
      t.integer :records_updated
      t.integer :records_skipped
      t.text :error_message
      t.text :warnings

      t.timestamps
    end
  end
end
