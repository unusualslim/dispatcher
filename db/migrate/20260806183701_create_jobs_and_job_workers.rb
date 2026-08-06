class CreateJobsAndJobWorkers < ActiveRecord::Migration[7.0]
  def change
    create_table :jobs do |t|
      t.references :production_order, null: false, foreign_key: true
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.string :job_type, null: false
      t.datetime :started_at, null: false
      t.datetime :ended_at

      t.timestamps
    end

    create_table :job_workers do |t|
      t.references :job, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :clocked_in_at, null: false
      t.datetime :clocked_out_at

      t.timestamps
    end
  end
end
