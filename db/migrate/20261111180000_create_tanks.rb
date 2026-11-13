# Tank monitoring, phase 1: tanks at locations, the feeds' own tanks (Kii sensors, Smartank tanks, the 0002 email's
# lines, spreadsheet tabs, manual entry) mapped onto them, and every reading the feeds send.
class CreateTanks < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/MethodLength, Metrics/AbcSize
    create_table :tanks do |t|
      t.references :location, null: false, foreign_key: true
      t.references :product, type: :string, foreign_key: true
      t.string :name, null: false
      t.string :ownership, null: false, default: 'managed'
      t.decimal :capacity_gallons, precision: 12, scale: 2
      t.decimal :fill_limit_gallons, precision: 12, scale: 2
      t.decimal :bottom_gallons, precision: 12, scale: 2
      t.boolean :active, null: false, default: true
      t.text :notes
      t.timestamps
    end

    create_table :feed_tanks do |t|
      t.string :feed, null: false
      t.string :external_id, null: false
      t.string :name
      t.references :tank, foreign_key: true
      t.boolean :ignored, null: false, default: false
      t.jsonb :details, null: false, default: {}
      t.datetime :last_read_at
      t.decimal :last_gallons, precision: 12, scale: 2
      t.string :last_status
      t.timestamps
      t.index %i[feed external_id], unique: true
    end

    create_table :tank_readings do |t|
      t.references :feed_tank, null: false, foreign_key: true, index: false
      t.datetime :read_at, null: false
      t.decimal :gallons, precision: 12, scale: 2, null: false
      t.decimal :water_inches, precision: 8, scale: 2
      t.decimal :temperature_f, precision: 6, scale: 2
      t.string :status
      t.references :sync_log, foreign_key: { on_delete: :nullify }
      t.datetime :created_at, null: false
      t.index %i[feed_tank_id read_at], unique: true
    end
  end
end
