# Who can do what. Admins can do everything; staff users get a level per area
# (view < edit < approve, each including the ones before it); drivers and line workers keep
# their own fixed screens and have no area access.
module UserPermissions
  extend ActiveSupport::Concern

  AREAS = {
    'sales' => 'Sales',
    'dispatch' => 'Dispatch',
    'production' => 'Production',
    'purchasing' => 'Purchasing',
    'inventory' => 'Inventory',
    'accounting' => 'Accounting'
  }.freeze
  LEVELS = %w[view edit approve].freeze

  ROLES = {
    'admin' => 'Admin',
    'staff' => 'Staff',
    'worker' => 'Driver',
    'line_worker' => 'Line Worker'
  }.freeze

  included do
    normalizes :permissions, with: ->(perms) { perms.to_h.stringify_keys.compact_blank }
    validate :permissions_are_known
  end

  def admin?
    role == 'admin'
  end

  def staff?
    role == 'staff'
  end

  def level_for(area)
    return 'approve' if admin?

    staff? ? permissions[area.to_s] : nil
  end

  def can?(area, level = :view)
    have = LEVELS.index(level_for(area))
    have.present? && have >= LEVELS.index(level.to_s)
  end

  # Areas this user can at least view, in sidebar order.
  def viewable_areas
    AREAS.keys.select { |area| can?(area) }
  end

  private

  def permissions_are_known
    bad = permissions.reject { |area, level| AREAS.key?(area) && LEVELS.include?(level) }
    errors.add(:permissions, "has unknown entries: #{bad.keys.join(', ')}") if bad.any?
  end
end
