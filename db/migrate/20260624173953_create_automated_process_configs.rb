class CreateAutomatedProcessConfigs < ActiveRecord::Migration[7.0]
  def change
    create_table :automated_process_configs do |t|
      t.string :slug
      t.string :schedule
      t.text :notes

      t.timestamps
    end
  end
end
