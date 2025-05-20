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

    def send_work_order_email(work_order)
      @work_order = work_order
      @user = User.find_by(id: work_order.assigned_to)
    
      # Check if the user has opted in for email notifications
      return unless @user&.email_opt_in
    
      mail(
        to: @user.email,
        subject: "Work Order ##{@work_order.id}"
      )
    end

    def new_comment_email(work_order, comment, user)
      @work_order = work_order
      @comment = comment
      @user = user
  
      mail(
        to: @user.email,
        subject: "New Comment on Work Order ##{@work_order.id}"
      )
    end
  end