# Custom roles: admins build roles (area levels, feature rights, data flags, assistant level) and give users
# any number of them; a user can do what any of their roles allows. Admins (and anyone) can also have data
# flags hidden from them (users.hidden_flags), which wins over roles.
#
# Existing staff keep exactly the access they have: one role per distinct area grid in use, with every feature
# and data flag of those areas (features and flags didn't exist, so nothing was restricted). users.permissions
# stays for now (dropped in a later deploy, see CLAUDE.md on live column removals).
class CreateRoles < ActiveRecord::Migration[8.1]
  AREA_LABELS = { 'sales' => 'Sales', 'dispatch' => 'Dispatch', 'production' => 'Production',
                  'purchasing' => 'Purchasing', 'inventory' => 'Inventory', 'accounting' => 'Accounting' }.freeze
  FEATURES = {
    'sales' => %w[quotes pricing_rules freight_setup customers],
    'purchasing' => %w[inventory_pos expense_pos vendors],
    'inventory' => %w[adjustments products],
    'production' => %w[quality],
    'accounting' => %w[gl_entries costing_setup]
  }.freeze
  FLAGS = %w[costs customer_pricing gl financial_dashboard].freeze

  class MigrationRole < ActiveRecord::Base
    self.table_name = 'roles'
  end

  def up
    create_tables
    add_column :users, :hidden_flags, :jsonb, null: false, default: []

    MigrationRole.reset_column_information
    roles_from_existing_access
  end

  def down
    remove_column :users, :hidden_flags
    drop_table :role_assignments
    drop_table :roles
  end

  private

  def create_tables
    create_table :roles do |t|
      t.string :name, null: false
      t.text :description
      t.jsonb :area_levels, null: false, default: {}
      %i[features data_flags].each { |list| t.jsonb list, null: false, default: [] }
      t.string :assistant_level, null: false, default: 'off'
      t.timestamps
    end
    add_index :roles, 'lower(name)', unique: true, name: 'index_roles_on_lower_name'
    create_assignments
  end

  def create_assignments
    create_table :role_assignments do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.timestamps
    end
    add_index :role_assignments, %i[user_id role_id], unique: true
  end

  def roles_from_existing_access
    existing_access.each do |levels, user_ids|
      role = MigrationRole.create!(name: role_name(levels), area_levels: levels, features: features_for(levels),
                                   data_flags: FLAGS, description: 'Created from the access users had before roles.')
      user_ids.each { |user_id| assign(user_id, role.id) }
    end
  end

  # { area levels (in sidebar order) => [user ids] } for staff with any access.
  def existing_access
    order = AREA_LABELS.keys
    select_rows("SELECT id, permissions::text FROM users WHERE role = 'staff' AND permissions <> '{}'::jsonb")
      .group_by { |_, perms| JSON.parse(perms).sort_by { |area, _| order.index(area) || 99 }.to_h }
      .transform_values { |rows| rows.map(&:first) }
  end

  def assign(user_id, role_id)
    execute('INSERT INTO role_assignments (user_id, role_id, created_at, updated_at) ' \
            "VALUES (#{user_id.to_i}, #{role_id.to_i}, NOW(), NOW())")
  end

  def role_name(levels)
    levels.map { |area, level| "#{AREA_LABELS.fetch(area, area)} #{level}" }.join(' · ')
  end

  def features_for(levels)
    levels.keys.flat_map { |area| FEATURES.fetch(area, []) }
  end
end
