class DispatchMailer < ApplicationMailer
    default from: 'no_reply@loadntrucks.com'

    def send_dispatch_email(dispatch)
        @origin_locations = Location.where(location_category_id: 1)
        @destination_locations = Location.where(location_category_id: 2)
        @user = User.find_by(id: dispatch.driver.id)
        @dispatch = dispatch
        mail(
            to: @user.email,
            subject: "Dispatch # #{dispatch.id}"
        )
    end
end
