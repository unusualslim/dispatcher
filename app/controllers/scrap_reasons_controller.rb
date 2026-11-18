# Production → Scrap Reasons: the list offered when scrap is recorded on a production order.
class ScrapReasonsController < ApplicationController
  permission_area :production

  def index
    @reasons = ScrapReason.ordered
    @reason = ScrapReason.new
  end

  def create
    reason = ScrapReason.new(name: new_name,
                             position: ScrapReason.maximum(:position).to_i + 1)
    if reason.save
      redirect_to scrap_reasons_path, notice: t('.added', name: reason.name)
    else
      redirect_to scrap_reasons_path, alert: reason.errors.full_messages.to_sentence
    end
  end

  def new_name
    params.dig(:scrap_reason, :name).to_s.strip
  end
  private :new_name

  def update
    reason = ScrapReason.find(params[:id])
    reason.update!(params.expect(scrap_reason: %i[name active]))
    redirect_to scrap_reasons_path, notice: t('.saved', name: reason.name)
  rescue ActiveRecord::RecordInvalid => e
    redirect_to scrap_reasons_path, alert: e.record.errors.full_messages.to_sentence
  end
end
