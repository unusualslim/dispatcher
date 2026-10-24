# frozen_string_literal: true

class Users::RegistrationsController < Devise::RegistrationsController
  before_action :configure_permitted_parameters, if: :devise_controller?
  skip_before_action :require_no_authentication, only: %i[new create]
  # Sign-up is how admins add users (Users page); it is not public.
  before_action :require_admin!, only: %i[new create]
  # before_action :configure_sign_up_params, only: [:create]
  # before_action :configure_account_update_params, only: [:update]

  # GET /resource/sign_up
  # def new
  #   super
  # end

  # POST /resource
  # def create
  #   super
  # end

  # GET /resource/edit
  # def edit
  #   super
  # end

  # PUT /resource
  # def update
  #   super
  # end

  # DELETE /resource
  # def destroy
  #   super
  # end

  # GET /resource/cancel
  # Forces the session data which is usually expired after sign
  # in to be expired now. This is useful if the user wants to
  # cancel oauth signing in/up in the middle of the process,
  # removing all OAuth session data.
  # def cancel
  #   super
  # end

  def new
    @user = User.new
    render 'users/registrations/new'
  end

  # POST /users
  def create
    @user = User.new(sign_up_params)

    if params['cf-turnstile-response'].blank?
      Rails.logger.warn '[Turnstile] No token submitted; the widget did not load or was not completed'
      flash.now[:alert] = t('users.registrations.turnstile_missing')
      return render :new, status: :unprocessable_entity
    end
    unless verify_turnstile
      flash.now[:alert] = t('users.registrations.turnstile_failed')
      return render :new, status: :unprocessable_entity
    end

    if @user.save
      redirect_to users_path, notice: "Created #{@user.email}."
    else
      render :new, status: :unprocessable_entity
    end
  end

  protected

  def configure_permitted_parameters
    # Permit additional parameters for account update. Not :role -- only admins change roles (Users page).
    devise_parameter_sanitizer.permit(:account_update, keys: %i[sms_opt_in email_opt_in phone_number])
    # Permit additional parameters for account sign up if needed
    devise_parameter_sanitizer.permit(:sign_up, keys: [:role])
  end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_sign_up_params
  #   devise_parameter_sanitizer.permit(:sign_up, keys: [:attribute])
  # end

  # If you have extra params to permit, append them to the sanitizer.
  # def configure_account_update_params
  #   devise_parameter_sanitizer.permit(:account_update, keys: [:attribute])
  # end

  # The path used after sign up.
  # def after_sign_up_path_for(resource)
  #   super(resource)
  # end

  # The path used after sign up for inactive accounts.
  # def after_inactive_sign_up_path_for(resource)
  #   super(resource)
  # end
  private

  def verify_turnstile
    token = params['cf-turnstile-response'].to_s
    return false if token.blank?

    secret = Rails.application.credentials.dig(:turnstile, :secret_key) ||
             ENV.fetch('TURNSTILE_SECRET_KEY', nil)
    return false if secret.blank?

    uri      = URI('https://challenges.cloudflare.com/turnstile/v0/siteverify')
    response = Net::HTTP.post_form(uri, 'secret' => secret, 'response' => token)
    JSON.parse(response.body)['success'] == true
  rescue StandardError => e
    Rails.logger.error "Turnstile verification error: #{e.message}"
    false
  end

  def sign_up_params
    params.require(:user).permit(:email, :password, :password_confirmation, :first_name, :last_name, :phone_number,
                                 :role)
  end
end
