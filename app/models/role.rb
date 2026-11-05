# A custom role built by admins (Admin → Roles): area levels, feature rights, data flags and the assistant
# level. Users can have any number; access adds up (UserPermissions).
class Role < ApplicationRecord
  has_many :role_assignments, dependent: :delete_all
  has_many :users, through: :role_assignments

  normalizes :name, with: ->(name) { name.to_s.squish }
  normalizes :area_levels, with: ->(levels) { levels.to_h.stringify_keys.compact_blank }
  normalizes :features, with: ->(list) { Array(list).map(&:to_s).compact_blank.uniq }
  normalizes :data_flags, with: ->(list) { Array(list).map(&:to_s).compact_blank.uniq }

  validates :name, presence: true, uniqueness: { case_sensitive: false }
  validates :assistant_level, inclusion: { in: User::ASSISTANT_LEVELS.keys }
  validate :entries_are_known

  scope :ordered, -> { order(Arel.sql('lower(name)')) }

  # "Sales edit · Dispatch view" for lists.
  def area_summary
    area_levels.map { |area, level| "#{User::AREAS[area]} #{level}" }.join(' · ').presence || 'No areas'
  end

  private

  def entries_are_known
    unknown(:area_levels, area_levels.keys.reject { |area| known_level?(area) })
    unknown(:features, features - User::FEATURES.keys)
    unknown(:data_flags, data_flags - User::DATA_FLAGS.keys)
  end

  def known_level?(area)
    User::AREAS.key?(area) && User::LEVELS.include?(area_levels[area])
  end

  def unknown(attribute, entries)
    errors.add(attribute, "has unknown entries: #{entries.join(', ')}") if entries.any?
  end
end
