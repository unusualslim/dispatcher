# Scrap on production orders: an addable list of reasons, and each scrap entry (what, how much, why).
class CreateScrapReasons < ActiveRecord::Migration[8.1]
  STARTERS = ['Spill or leak', 'Damaged packaging', 'Off-spec / failed quality', 'Mislabeled', 'Line changeover',
              'Other'].freeze

  def up # rubocop:disable Metrics/AbcSize, Metrics/MethodLength
    create_table :scrap_reasons do |t|
      t.string :name, null: false
      t.boolean :active, null: false, default: true
      t.integer :position
      t.timestamps
      t.index :name, unique: true
    end

    create_table :production_order_scraps do |t|
      t.references :production_order, null: false, foreign_key: { on_delete: :cascade }
      t.references :scrap_reason, null: false, foreign_key: true
      t.references :product, type: :string, foreign_key: true
      t.decimal :quantity, precision: 14, scale: 3, null: false
      t.text :notes
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    now = Time.current
    rows = STARTERS.each_with_index.map { |name, i| { name: name, position: i + 1, created_at: now, updated_at: now } }
    safety_assured { execute_insert(rows) } # a table created just above: nothing else reads it yet
  end

  def down
    drop_table :production_order_scraps
    drop_table :scrap_reasons
  end

  private

  def execute_insert(rows)
    rows.each do |row|
      execute ActiveRecord::Base.sanitize_sql_array(
        ['INSERT INTO scrap_reasons (name, position, active, created_at, updated_at) VALUES (?, ?, true, ?, ?)',
         row[:name], row[:position], row[:created_at], row[:updated_at]]
      )
    end
  end
end
