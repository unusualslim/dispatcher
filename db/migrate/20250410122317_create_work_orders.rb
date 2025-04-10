class CreateWorkOrders < ActiveRecord::Migration[7.0]
  def change
    create_table :work_orders do |t|
      t.string :subject
      t.references :location, null: false, foreign_key: true
      t.integer :assigned_to
      t.string :attachments
      t.references :vendor, null: false, foreign_key: true
      t.string :status
      t.text :description

      t.timestamps
    end
  end
end
