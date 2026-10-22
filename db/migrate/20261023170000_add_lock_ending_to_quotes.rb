class AddLockEndingToQuotes < ActiveRecord::Migration[7.0]
  def change
    # Ending a price lock early: the quote's expiry_date stays as quoted to the
    # customer; lock_ended_on is the first day orders go back to the live rules.
    add_column :quotes, :lock_ended_on,   :date
    add_column :quotes, :lock_ended_at,   :datetime
    add_column :quotes, :lock_end_reason, :text
    add_reference :quotes, :lock_ended_by, foreign_key: { to_table: :users }
  end
end
