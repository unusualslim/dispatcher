class CreateComments < ActiveRecord::Migration[7.0]
  def change
    create_table :comments do |t|
      t.text :content
      t.references :user, null: false, foreign_key: true
      t.references :work_order, null: false, foreign_key: true

      t.timestamps
    end
  end
end
