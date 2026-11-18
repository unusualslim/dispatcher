# Audit trail (paper_trail): one row per create / update / destroy of a tracked record, with who did it and what
# changed. item_id is text because products are keyed by their PDI item number. Kept 5 years (AuditTrailPruneJob).
class CreateVersions < ActiveRecord::Migration[8.1]
  def change # rubocop:disable Metrics/MethodLength
    create_table :versions do |t|
      t.string :item_type, null: false
      t.string :item_id, null: false
      t.string :event, null: false
      t.string :whodunnit
      t.jsonb :object
      t.jsonb :object_changes
      t.datetime :created_at
      t.index %i[item_type item_id]
      t.index :created_at
    end
  end
end
