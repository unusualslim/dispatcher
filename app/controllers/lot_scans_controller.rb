# The page a batch label's QR code opens (/lot/:lot): product, lot, made date and PDI batch for the crew.
# Like the old /l labels (BatchController) it sits outside Devise: anyone signed in sees it, and the crew
# without accounts gets in with the batch label password (the same /gate session).
class LotScansController < ActionController::Base # rubocop:disable Rails/ApplicationController -- outside Devise on purpose
  layout 'batch'

  before_action :require_gate_or_user

  def show
    @label = BatchLabel.for_lot(params[:lot])
    render :not_found, status: :not_found unless @label
  end

  private

  def require_gate_or_user
    return if session[:batch_gate_ok] || user_signed_in?

    redirect_to gate_path(return_to: request.fullpath)
  end
end
