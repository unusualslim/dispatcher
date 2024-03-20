class DispatchMailer < ApplicationMailer
    default from: 'no_reply@loadntrucks.com'

    def send_dispatch_email(dispatch)
        
        @user = User.find_by(id: dispatch.driver.id)
        @dispatch = dispatch
        mail(
            to: @user.email,
            subject: "Dispatch # #{dispatch.id}"
        )
    end
end
