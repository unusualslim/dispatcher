class DispatchMessagesController < ApplicationController
  permission_area :dispatch

  def index
    @dispatch_messages = DispatchMessage.all

    # Filter by user_id if the parameter exists.
    @dispatch_messages = @dispatch_messages.where(user_id: params[:user_id]) if params[:user_id].present?

    @dispatch_messages = @dispatch_messages.order(sent_at: :desc).paginate(page: params[:page], per_page: 10)
  end

  def show
    @dispatch_message = DispatchMessage.find(params[:id])
  end
end
