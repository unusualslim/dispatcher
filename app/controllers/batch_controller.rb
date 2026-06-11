# Batch QR Label Controller
#
# SETUP — two values must be configured:
#   Rails credentials:  batch_qr:
#                         password: "your-crew-password"
#                         secret:   "long-random-string-for-encryption"
#   Or set ENV["BATCH_QR_PASSWORD"] and ENV["BATCH_QR_SECRET"].
#
# Inherits from ActionController::Base (not ApplicationController) so Devise's
# authenticate_user! does not apply. The session gate is independent.
#
class BatchController < ActionController::Base
  layout "batch"
  protect_from_forgery with: :exception
  wrap_parameters false

  before_action :require_gate, except: [:gate, :authenticate]

  def gate
    redirect_to(safe_return_path || labels_path) if session[:batch_gate_ok]
  end

  def authenticate
    password = Rails.application.credentials.dig(:batch_qr, :password) ||
               ENV["BATCH_QR_PASSWORD"]
    if password.present? &&
       ActiveSupport::SecurityUtils.secure_compare(params[:password].to_s, password)
      session[:batch_gate_ok] = true
      redirect_to safe_return_path || labels_path
    else
      flash.now[:alert] = "Incorrect password."
      render :gate, status: :unprocessable_entity
    end
  end

  def new; end

  def encode
    items = params.require(:items)
    crypt  = encryptor
    labels = Array(items).map do |item|
      token = crypt.encrypt_and_sign({
        "b" => item[:batch].to_s,
        "d" => item[:date].to_s,
        "p" => item[:product].to_s,
        "n" => item[:notes].to_s
      })
      { url: label_url(d: token) }
    end
    render json: { labels: labels }
  end

  def show
    data     = encryptor.decrypt_and_verify(params[:d].to_s)
    @batch   = data["b"]
    @date    = data["d"]
    @product = data["p"]
    @notes   = data["n"]
  rescue ActiveSupport::MessageEncryptor::InvalidMessage,
         ActiveSupport::MessageVerifier::InvalidSignature
    render :invalid, status: :unprocessable_entity
  end

  private

  def require_gate
    return if session[:batch_gate_ok]
    redirect_to gate_path(return_to: request.fullpath)
  end

  # Only allow same-site paths (start with / but not //).
  def safe_return_path
    path = params[:return_to].to_s
    path if path.start_with?("/") && !path.start_with?("//")
  end

  def encryptor
    secret = Rails.application.credentials.dig(:batch_qr, :secret) ||
             ENV["BATCH_QR_SECRET"]
    raise ArgumentError, "BATCH_QR_SECRET is not configured" if secret.blank?
    key = ActiveSupport::KeyGenerator.new(secret).generate_key("batch_qr_labels", 32)
    ActiveSupport::MessageEncryptor.new(key)
  end
end
