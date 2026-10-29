# Calculate freight on a dispatch: every order's customer charges on its own lane, and the carrier cost for the
# load when the carrier prices per dispatch (farthest stop + additional stops, split over the orders by gallons).
class DispatchFreightsController < ApplicationController
  permission_area :dispatch

  def create
    dispatch = Dispatch.find(params[:dispatch_id])
    result = Freight::DispatchCalculator.new(dispatch).apply!
    flash_type = result.warnings.any? ? :alert : :notice
    redirect_to dispatch_path(dispatch, anchor: 'freight'), flash_type => [message(result), *result.warnings].join(' ')
  end

  private

  def message(result)
    return t('.calculated') unless result.summary

    t('.priced', total: helpers.number_to_currency(result.summary[:total]))
  end
end
