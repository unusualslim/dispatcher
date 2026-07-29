class CreateUserFavorites < ActiveRecord::Migration[7.0]
  def change
    create_table :user_favorites do |t|
      t.references :user, null: false, foreign_key: true
      t.string :label
      t.string :path
      t.integer :position

      t.timestamps
    end
    add_index :user_favorites, [:user_id, :path], unique: true
  end
end
