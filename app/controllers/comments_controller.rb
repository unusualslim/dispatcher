class CommentsController < ApplicationController
    def create
        @work_order = WorkOrder.find(params[:work_order_id])
        @comment = @work_order.comments.build(comment_params)
        @comment.user = current_user # Assuming you have a `current_user` method for authentication

        if @comment.save
            # Send email to the assigned user
            if @work_order.assigned_to.present?
            assigned_user = User.find_by(id: @work_order.assigned_to)
            DispatchMailer.new_comment_email(@work_order, @comment, assigned_user).deliver_later if assigned_user&.email.present?
            end

            redirect_to @work_order, notice: "Comment was successfully posted."
        else
            redirect_to @work_order, alert: "Comment cannot be blank."
        end
    end
  
    private
  
    def comment_params
      params.require(:comment).permit(:content)
    end
  end