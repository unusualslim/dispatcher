# Posted GL journal entries (FPST production journals) with their lines frozen at posting time.
class CreateLedger < ActiveRecord::Migration[7.2]
  def change
    create_ledger_entries
    add_ledger_entry_links
    create_ledger_lines
  end

  private

  def create_ledger_entries
    create_table :ledger_entries do |t|
      t.string   :reference_number, null: false, index: { unique: true }
      t.date     :reference_date, null: false
      t.string   :description, null: false
      t.string   :journal_id, null: false
      t.string   :status, null: false, default: 'approved' # approved → exported
      t.datetime :approved_at, null: false
      t.datetime :exported_at
      t.timestamps
    end
  end

  def add_ledger_entry_links
    add_reference :ledger_entries, :production_order, foreign_key: true
    add_reference :ledger_entries, :reversal_of, foreign_key: { to_table: :ledger_entries }, index: { unique: true }
    add_reference :ledger_entries, :approved_by, foreign_key: { to_table: :users }
    add_reference :ledger_entries, :sync_log, foreign_key: true
  end

  def create_ledger_lines
    create_table :ledger_lines do |t|
      t.references :ledger_entry, null: false, foreign_key: true
      t.integer :position, null: false
      t.string  :posting
      t.string  :account, null: false # Site-Major-Sub
      t.string  :line_description, null: false
      t.decimal :debit, precision: 12, scale: 2
      t.decimal :credit, precision: 12, scale: 2
      t.timestamps
    end
  end
end
