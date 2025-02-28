class ApplicationMailer < ActionMailer::Base
  default from: "from@example.com"
  layout "mailer"

  # Log email after sending
  #after_action :log_email

  private

  def log_email
    return unless @user && mail

    # Use the MessageLogger service to log the email
    MessageLogger.log(
      @dispatch,
      mail.body.encoded,
      "email",
      "sent",
      mail.message_id
    )
  end
end
