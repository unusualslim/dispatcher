class CreateAnnouncements < ActiveRecord::Migration[7.0]
  def change
    create_table :announcements do |t|
      t.string :title
      t.text :content
      t.datetime :published_at
      t.string :status

      t.timestamps
    end
  end
end
