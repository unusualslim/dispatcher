class DispatchMailer < ApplicationMailer
    default from: 'no_reply@loadntrucks.com'

    def send_dispatch_email(dispatch, email_message)
      @dispatch = dispatch
      @user = dispatch.driver
      @message_body = email_message
  
      # Check if the user has opted in for email notifications
      return unless @user&.email_opt_in
  
      mail(
        to: @user.email,
        subject: "Dispatch # #{@dispatch.id}",
        body: @message_body
      )
      
    end
  end