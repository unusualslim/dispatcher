# rubocop:disable Metrics/MethodLength -- table definitions read best whole
# GL accounts (Major-Sub) for categories whose inventory the app posts (post_inventory_gl), and the link
# from each posted inventory movement to its FPST entry.
class AddInventoryGlAccounts < ActiveRecord::Migration[7.2]
  def change
    change_table :reporting_groups, bulk: true do |t|
      t.string :inventory_gl_account
      t.string :cogs_gl_account
      t.string :ppv_gl_account
      t.string :receipts_clearing_gl_account
      t.string :adjustment_gl_account
      t.string :revaluation_gl_account
    end

    # gl_posted_at is set even when a document's movements net to nothing (no entry).
    add_reference :inventory_transactions, :ledger_entry, foreign_key: true
    add_column :inventory_transactions, :gl_posted_at, :datetime

    add_reference :ledger_entries, :source, polymorphic: true
  end
end
# rubocop:enable Metrics/MethodLength
