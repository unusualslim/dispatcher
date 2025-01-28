class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  # Log email after sending
  after_action :log_email

  private

  def log_email
    return unless @user && mail

    # Use the MessageLogger service to log the email
    MessageLogger.log(
      user: @user,
      message_body: mail.body.raw_source,
      delivery_method: "Email",
      reference_id: mail.message_id,
      status: "sent",
      sent_at: Time.current
    )
  end
end
