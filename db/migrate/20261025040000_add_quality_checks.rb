# rubocop:disable Metrics/MethodLength, Metrics/AbcSize -- table definitions read best whole
# Quality checks move from PDI batches to the production order: products define the tests and
# target ranges; each order records its results; out-of-range results are reviewed afterwards.
class AddQualityChecks < ActiveRecord::Migration[7.2]
  def change
    # result_type: numeric (value against min/max) or pass_fail (against an expected description,
    # e.g. Appearance "clear and free from suspended matter"); test_method e.g. "ASTM D4052".
    create_table :quality_specs do |t|
      t.string  :product_id, null: false, index: true
      t.string  :section # groups checks on the certificate, e.g. "Elemental Analysis"
      t.string  :name, null: false
      t.string  :test_method
      t.string  :result_type, null: false, default: 'numeric'
      t.string  :expected
      t.string  :unit
      t.decimal :target_min, precision: 12, scale: 4
      t.decimal :target_max, precision: 12, scale: 4
      t.integer :position
      t.timestamps
    end

    create_quality_results
    # Printed under the results, e.g. "Methods based on ISO 22241-2".
    add_column :products, :coa_note, :string
    add_column :production_orders, :lot_number, :string
    add_index :production_orders, :lot_number, unique: true
    # Lets reopening/voiding reverse each inventory move exactly once.
    add_reference :inventory_transactions, :reversal_of, foreign_key: { to_table: :inventory_transactions },
                                                         index: { unique: true }
  end

  private

  # The spec's name, method, type and range are copied so later spec edits don't rewrite results.
  def create_quality_results
    create_table :quality_results do |t|
      t.references :production_order, null: false, foreign_key: true
      t.references :quality_spec, foreign_key: { on_delete: :nullify }
      t.string     :section
      t.string     :name, null: false
      t.string     :test_method
      t.string     :result_type, null: false, default: 'numeric'
      t.string     :expected
      t.string     :unit
      t.decimal    :target_min, precision: 12, scale: 4
      t.decimal    :target_max, precision: 12, scale: 4
      t.string     :qualifier # "<" or ">" for results at a detection limit, e.g. "< 0.5"
      t.decimal    :value, precision: 12, scale: 4 # numeric checks
      t.boolean    :passed # rubocop:disable Rails/ThreeStateBooleanColumn -- nil for numeric checks
      t.boolean    :in_range, null: false, default: false
      t.text       :notes
      t.references :tested_by, foreign_key: { to_table: :users }
      t.datetime   :tested_at, null: false
      t.references :reviewed_by, foreign_key: { to_table: :users }
      t.datetime   :reviewed_at
      t.text       :resolution
      t.timestamps
    end
    add_index :quality_results, %i[production_order_id quality_spec_id], unique: true
  end
end
# rubocop:enable Metrics/MethodLength, Metrics/AbcSize
