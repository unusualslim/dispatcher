class MessagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, only: :reply
  # The Twilio webhook is public, so only act on requests Twilio signed with our auth token.
  before_action :verify_twilio_signature, only: :reply

  def reply
    from_number = params['From']
    boot_twilio

    user = User.find_by(phone_number: from_number)
    return unless user&.sms_opt_in # Check if the user has opted in for SMS

    sms = @client.messages.create(
      from: Rails.application.credentials.twilio_number,
      to: from_number,
      body: "Hello there, thanks for texting me. Your number is #{from_number}."
    )

    # Log the SMS message
    DispatchMessage.create!(
      user_id: user.id, # Use the found user
      message_body: sms.body,
      delivery_method: 'SMS',
      reference_id: sms.sid, # Twilio's unique identifier for the message
      status: 'sent',
      sent_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send or log SMS message: #{e.message}")
  end

  private

  def boot_twilio
    account_sid = Rails.application.credentials.twilio_sid
    @client = Twilio::REST::Client.new(account_sid, twilio_auth_token)
  end

  def twilio_auth_token
    Rails.application.credentials.twilio_token
  end

  def verify_twilio_signature
    validator = Twilio::Security::RequestValidator.new(twilio_auth_token.to_s)
    return if validator.validate(request.original_url, request.POST, request.headers['X-Twilio-Signature'].to_s)

    Rails.logger.warn("Rejected #{request.method} #{request.path}: invalid or missing X-Twilio-Signature")
    head :forbidden
  end
end
