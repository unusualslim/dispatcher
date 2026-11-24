# Exception-based management: one review record per exception someone has dealt with. kind + subject_key name the
# exception (e.g. "receipt_ppv" / "txn:123"); fingerprint is the situation reviewed (e.g. standard and cost at the
# time), so a state-based exception comes back when the numbers change.
class CreateExceptionReviews < ActiveRecord::Migration[8.1]
  def change
    create_table :exception_reviews do |t|
      t.string :kind, null: false
      t.string :subject_key, null: false
      t.string :fingerprint, null: false, default: ''
      t.text :resolution, null: false
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime :reviewed_at, null: false
      t.timestamps
    end
    add_index :exception_reviews, %i[kind subject_key fingerprint], unique: true
  end
end
