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

    def send_work_order_email(work_order, email_message)
      @work_order = work_order
      @user = User.find_by(id: work_order.assigned_to)
      @message_body = email_message
  
      # Check if the user has opted in for email notifications
      return unless @user&.email_opt_in
  
      mail(
        to: @user.email,
        subject: "Work Order ##{@work_order.id}",
        body: @message_body
      )
    end
  end