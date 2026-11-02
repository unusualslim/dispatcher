# PATCH /home_page: the signed-in user picks their own home page (sidebar right-click or My Account).
# Blank resets to the role's default. Admins set other users' on the Users form.
class HomePagesController < ApplicationController
  def update
    return deny_access unless HomePage.choosable?(current_user)

    current_user.update(home_page: params[:path]) ? saved : failed(current_user.errors.full_messages.to_sentence)
  end

  private

  def saved
    respond_to do |format|
      format.json { render json: { home_page: current_user.home_page } }
      format.html { redirect_back_or_to edit_user_registration_path, notice: t('.updated') }
    end
  end

  def failed(message)
    respond_to do |format|
      format.json { render json: { error: message }, status: :unprocessable_content }
      format.html { redirect_back_or_to edit_user_registration_path, alert: message }
    end
  end
end
