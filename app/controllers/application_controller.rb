# frozen_string_literal: true

# Base controller: Devise auth, role checks and the selected warehouse.
class ApplicationController < ActionController::Base
  before_action :configure_permitted_parameters, if: :devise_controller?
  before_action :authenticate_user!

  helper_method :admin?, :driver?, :line_worker?, :can?, :home_path, :current_warehouse, :warehouse_stock_for

  # Landing page for each area, used to send staff somewhere they can see.
  AREA_HOME = {
    'sales' => :dashboard_customer_orders_path,
    'dispatch' => :dispatches_path,
    'production' => :dashboard_production_orders_path,
    'purchasing' => :dashboard_purchase_orders_path,
    'inventory' => :inventory_intelligence_path,
    'accounting' => :ledger_entries_path
  }.freeze

  class_attribute :area_rules, instance_writer: false

  # Puts a controller in an area. GET requests need View, other requests Edit, and the listed
  # `approve` actions Approve. Deleting (destroy*) always needs Admin. `lookups` (search/select2
  # used by forms in other areas) only need some staff access; `areas` moves single actions to
  # another area.
  def self.permission_area(area, approve: [], lookups: [], areas: {}, **filter)
    self.area_rules = { area: area.to_s, approve: approve.map(&:to_s), lookups: lookups.map(&:to_s),
                        areas: areas.transform_keys(&:to_s).transform_values(&:to_s) }
    before_action :authorize_area!, **filter
  end

  def admin?
    user_signed_in? && current_user.role == 'admin'
  end

  def driver?
    user_signed_in? && current_user.role == 'worker'
  end

  def line_worker?
    user_signed_in? && current_user.role == 'line_worker'
  end

  def current_warehouse
    return nil unless session[:warehouse_id].present?

    @current_warehouse ||= Location.find_by(id: session[:warehouse_id])
  end

  # Returns stock for a product scoped to the active warehouse,
  # or global current_stock when no warehouse is selected.
  def warehouse_stock_for(product)
    return product.current_stock unless current_warehouse

    product.stock_at(current_warehouse)
  end

  def can?(area, level = :view)
    user_signed_in? && current_user.can?(area, level)
  end

  def require_admin!
    return if admin?

    deny_access
  end

  # Any staff access at all (help pages, form lookups, the warehouse picker).
  def require_any_access!
    deny_access unless admin? || current_user&.viewable_areas&.any?
  end

  def authorize_area!
    rules = area_rules
    return require_admin! if action_name.start_with?('destroy') # deleting is admin-only everywhere
    return require_any_access! if rules[:lookups].include?(action_name)

    area = rules[:areas].fetch(action_name, rules[:area])
    deny_access unless can?(area, required_level(rules))
  end

  def required_level(rules)
    return :approve if rules[:approve].include?(action_name)

    request.get? || request.head? ? :view : :edit
  end

  def deny_access
    respond_to do |format|
      # A denied button press goes back to the page it came from; a denied page goes home.
      format.html do
        alert = t('access.denied')
        request.get? ? redirect_to(home_path, alert: alert) : redirect_back_or_to(home_path, alert: alert)
      end
      format.any { head :forbidden }
    end
  end

  def home_path
    return new_user_session_path unless user_signed_in?
    return line_path if line_worker?
    return dispatches_path if driver? || admin?

    area = current_user.viewable_areas.first
    area ? send(AREA_HOME[area]) : edit_user_registration_path
  end

  def after_sign_in_path_for(resource)
    return home_path if resource.staff?

    resource.role == 'line_worker' ? line_path : dispatches_path
  end

  protected

  def configure_permitted_parameters
    devise_parameter_sanitizer.permit(:sign_up, keys: %i[sms_opt_in first_name last_name phone_number])
    devise_parameter_sanitizer.permit(:account_update,
                                      keys: %i[sms_opt_in email_opt_in first_name last_name phone_number])
  end
end
