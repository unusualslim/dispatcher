# Who can do what.
#
# Staff get access from their roles (Admin → Roles), as many as needed; access adds up: the highest area level
# of any role, and any feature right or data flag that any role grants. Admins can do everything. Anyone can
# have data flags hidden from them (users.hidden_flags), and hiding wins over roles and admin, so an admin
# can be kept out of financial data. Drivers and line workers keep their own fixed screens.
#
#   area levels   view < edit < approve per area (each includes the ones before it)
#   feature rights  what someone may change inside an area, on top of its Edit level
#   data flags    sensitive data that cuts across areas (pages and figures shown only with the flag)
#   assistant     who may use the AI assistant, and how far
module UserPermissions
  extend ActiveSupport::Concern

  include AccessCatalog

  # What a user ends up with once roles, admin and hidden flags are combined.
  Access = Struct.new(:levels, :features, :flags, :assistant, keyword_init: true)

  included do
    has_many :role_assignments, dependent: :delete_all
    has_many :roles, through: :role_assignments

    normalizes :hidden_flags, with: ->(flags) { Array(flags).map(&:to_s).compact_blank.uniq }
    validate :hidden_flags_are_known
  end

  def admin?
    role == 'admin'
  end

  def staff?
    role == 'staff'
  end

  def access
    @access ||= admin? ? admin_access : staff_access
  end

  def reload(*)
    @access = nil
    super
  end

  def level_for(area)
    access.levels[area.to_s]
  end

  def can?(area, level = :view)
    have = LEVELS.index(level_for(area))
    have.present? && have >= LEVELS.index(level.to_s)
  end

  # A feature right (on top of its area's Edit level).
  def can_feature?(feature)
    access.features.include?(feature.to_s)
  end

  # A data flag (sensitive data).
  def sees?(flag)
    access.flags.include?(flag.to_s)
  end

  # Areas this user can at least view, in sidebar order.
  def viewable_areas
    AREAS.keys.select { |area| can?(area) }
  end

  private

  def admin_access
    Access.new(levels: AREAS.keys.index_with('approve'), features: FEATURES.keys.to_set,
               flags: (DATA_FLAGS.keys - hidden_flags).to_set, assistant: 'query')
  end

  def staff_access
    grants = staff? ? roles.to_a : []
    Access.new(levels: highest_levels(grants), features: grants.flat_map(&:features).to_set & FEATURES.keys,
               flags: (grants.flat_map(&:data_flags) - hidden_flags).to_set & DATA_FLAGS.keys,
               assistant: highest_assistant(grants))
  end

  def highest_assistant(grants)
    grants.map(&:assistant_level).max_by { |level| ASSISTANT_LEVELS.keys.index(level).to_i } || 'off'
  end

  def highest_levels(grants)
    grants.flat_map { |role| role.area_levels.to_a }.group_by(&:first)
          .transform_values { |pairs| pairs.map(&:last).max_by { |level| LEVELS.index(level).to_i } }
          .slice(*AREAS.keys)
  end

  def hidden_flags_are_known
    unknown = hidden_flags - DATA_FLAGS.keys
    errors.add(:hidden_flags, "has unknown entries: #{unknown.join(', ')}") if unknown.any?
  end
end
