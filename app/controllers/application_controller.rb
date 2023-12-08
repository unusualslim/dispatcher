class ApplicationController < ActionController::Base
    before_action :configure_permitted_parameters, if: :devise_controller?
    before_action :authenticate_user!

    protected
  
    def configure_permitted_parameters
      devise_parameter_sanitizer.permit(:sign_up, keys: [:sms_opt_in, :first_name, :last_name, :phone_number])
      devise_parameter_sanitizer.permit(:account_update, keys: [:sms_opt_in, :email_opt_in, :first_name, :last_name, :phone_number])
    end
end
