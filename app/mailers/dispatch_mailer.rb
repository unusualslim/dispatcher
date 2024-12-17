class DispatchMailer < ApplicationMailer
    default from: 'no_reply@loadntrucks.com'

    def send_dispatch_email(dispatch, email_message)
        @dispatch = dispatch
        @user = dispatch.driver
        @email_message = email_message
    
        mail(
          to: @user.email,
          subject: "Dispatch # #{@dispatch.id}",
          body: @email_message # This is the custom message passed from the controller
        )
      end
end
