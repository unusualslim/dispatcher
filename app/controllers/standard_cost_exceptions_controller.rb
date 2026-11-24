# Accounting → Standard Cost Exceptions (StandardCostExceptions): receipt and production variances outside the
# tolerance, standards that no longer match current cost, and items with no standard. Someone with Accounting
# approval records what was done, which takes the item off the list.
class StandardCostExceptionsController < ApplicationController
  permission_area :accounting, flag: :costs, approve: %i[review], features: { update_settings: :costing_setup }

  def index
    @show_reviewed = params[:reviewed] == '1'
    @kind = params[:kind].presence_in(StandardCostExceptions::KINDS.keys)
    items = StandardCostExceptions.new.items
    open_items = items.reject(&:reviewed?)
    @counts = open_items.map(&:kind).tally
    @open_count = open_items.size
    @items = shown(@show_reviewed ? items.select(&:reviewed?) : open_items)
  end

  def review
    ExceptionReview.record!(**review_params, user: current_user)
    redirect_to back_to_list, notice: t('.reviewed')
  rescue ArgumentError => e
    redirect_to back_to_list, alert: e.message
  end

  def update_settings
    StandardCostExceptions::SETTINGS.each_key do |key|
      AppSetting.set(key, params[key].to_d.clamp(0, 100_000).to_s) if params[key].present?
    end
    redirect_to standard_cost_exceptions_path, notice: t('.saved')
  end

  private

  def review_params
    { kind: params[:kind_key], subject_key: params[:subject_key], fingerprint: params[:fingerprint],
      resolution: params[:resolution] }
  end

  def back_to_list = standard_cost_exceptions_path(kind: params[:kind])

  def shown(items) = @kind ? items.select { |i| i.kind == @kind } : items
end
