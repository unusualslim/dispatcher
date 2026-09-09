class ApplicationController < ActionController::Base
    before_action :configure_permitted_parameters, if: :devise_controller?
    before_action :authenticate_user!

    helper_method :admin?, :driver?, :line_worker?, :current_warehouse, :warehouse_stock_for

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

    def require_admin!
      unless admin?
        redirect_to dispatches_path, alert: "Access denied."
      end
    end

    def after_sign_in_path_for(resource)
      if resource.role == 'worker'
        dispatches_path
      else
        authenticated_root_path
      end
    end

    protected

    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:sms_opt_in, :first_name, :last_name, :phone_number])
      devise_parameter_sanitizer.permit(:account_update, keys: [:sms_opt_in, :email_opt_in, :first_name, :last_name, :phone_number])
    end
end
