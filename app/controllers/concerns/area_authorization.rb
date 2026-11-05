# Area access for controllers (UserPermissions): `permission_area` puts a controller in an area, and
# authorize_area! checks the area level, the data flag and the feature right of each request.
module AreaAuthorization
  extend ActiveSupport::Concern

  RULE_KEYS = %i[approve lookups areas feature features flag flags].freeze

  included do
    class_attribute :area_rules, instance_writer: false
    helper_method :can?, :can_feature?, :sees?, :can_see?
  end

  class_methods do
    # Puts a controller in an area. GET requests need View, other requests Edit, and the listed `approve`
    # actions Approve. Deleting (destroy*) always needs Admin. `lookups` (search/select2 used by forms in other
    # areas) only need some staff access; `areas` moves single actions to another area.
    # `feature` (or per action `features: { action: feature }`): a feature right needed to change things
    # (new/edit forms and every non-GET request). `flag` (or `flags: { action: flag }`): a data flag needed to
    # see the page at all (UserPermissions::DATA_FLAGS). Anything else (only:, if:, unless:) goes to before_action.
    def permission_area(area, **options)
      self.area_rules = normalize_rules(area, options.extract!(*RULE_KEYS))
      before_action :authorize_area!, **options
    end

    private

    def normalize_rules(area, rules)
      lists = %i[approve lookups].index_with { |key| Array(rules[key]).map(&:to_s) }
      by_actions = %i[areas features flags].index_with { |key| by_action(rules[key]) }
      { area: area.to_s, feature: rules[:feature]&.to_s, flag: rules[:flag]&.to_s, **lists, **by_actions }
    end

    def by_action(hash)
      (hash || {}).to_h { |action, value| [action.to_s, value.to_s] }
    end
  end

  def can?(area, level = :view)
    user_signed_in? && current_user.can?(area, level)
  end

  def can_feature?(feature)
    user_signed_in? && current_user.can_feature?(feature)
  end

  def sees?(flag)
    user_signed_in? && current_user.sees?(flag)
  end

  # An area at View level, plus a data flag when one is given.
  def can_see?(area, flag = nil)
    can?(area) && (flag.blank? || sees?(flag))
  end

  # For actions that pick their feature right at run time (e.g. by PO type).
  def require_feature!(feature)
    deny_access unless can_feature?(feature)
  end

  private

  def authorize_area!
    return require_admin! if action_name.start_with?('destroy') # deleting is admin-only everywhere
    return require_any_access! if area_rules[:lookups].include?(action_name)

    deny_access unless area_level_ok? && data_flag_ok? && feature_ok?
  end

  def area_level_ok?
    can?(area_rules[:areas].fetch(action_name, area_rules[:area]), required_level)
  end

  def data_flag_ok?
    flag = area_rules[:flags].fetch(action_name, area_rules[:flag])
    flag.blank? || sees?(flag)
  end

  def feature_ok?
    feature = area_rules[:features].fetch(action_name) { area_rules[:feature] if changing? }
    feature.blank? || can_feature?(feature)
  end

  # Forms and every request that changes something.
  def changing?
    %w[new edit].include?(action_name) || !reading?
  end

  def reading?
    request.get? || request.head?
  end

  def required_level
    return :approve if area_rules[:approve].include?(action_name)

    reading? ? :view : :edit
  end
end
