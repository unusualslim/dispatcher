class MessagesController < ApplicationController
  skip_before_action :verify_authenticity_token
  skip_before_action :authenticate_user!, only: :reply

  def reply
    message_body = params["Body"]
    from_number = params["From"]
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
      delivery_method: "SMS",
      reference_id: sms.sid, # Twilio's unique identifier for the message
      status: "sent",
      sent_at: Time.current
    )
  rescue StandardError => e
    Rails.logger.error("Failed to send or log SMS message: #{e.message}")
  end

  private

  def boot_twilio
    account_sid = Rails.application.credentials.twilio_sid
    auth_token = Rails.application.credentials.twilio_token
    @client = Twilio::REST::Client.new(account_sid, auth_token)
  end
end
