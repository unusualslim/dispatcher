class ApplicationController < ActionController::Base
    before_action :configure_permitted_parameters, if: :devise_controller?
    before_action :authenticate_user!

    helper_method :admin?, :driver?

    def admin?
      user_signed_in? && current_user.role == 'admin'
    end

    def driver?
      user_signed_in? && current_user.role == 'worker'
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
