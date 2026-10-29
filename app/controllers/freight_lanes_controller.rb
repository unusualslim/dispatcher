# Standard miles per origin → destination: added and edited on a location's Freight tab, or pasted in bulk on
# Freight Rules → Lanes.
class FreightLanesController < ApplicationController
  permission_area :sales

  def create
    lane = FreightLane.find_or_initialize_by(lane_params.slice(:origin_location_id, :destination_location_id))
    lane.assign_attributes(lane_params)
    if lane.save
      after_save_redirect(lane)
    else
      redirect_back_or_to freight_rules_path(tab: 'lanes'), alert: lane.errors.full_messages.to_sentence
    end
  end

  def update
    lane = FreightLane.find(params[:id])
    if lane.update(lane_params.slice(:standard_miles, :notes))
      redirect_back_or_to freight_rules_path(tab: 'lanes'), notice: t('.saved')
    else
      redirect_back_or_to freight_rules_path(tab: 'lanes'), alert: lane.errors.full_messages.to_sentence
    end
  end

  def destroy
    FreightLane.find(params[:id]).destroy!
    redirect_back_or_to freight_rules_path(tab: 'lanes'), notice: t('.deleted')
  end

  # Pasted "origin, destination, miles" rows (location IDs or exact names); adds new lanes, updates existing ones.
  def import
    result = Freight::LaneImport.new(params[:rows].to_s).call
    if result.errors.any?
      redirect_to freight_rules_path(tab: 'lanes'), alert: result.errors.first(5).join(' ')
    else
      redirect_to freight_rules_path(tab: 'lanes'), notice: t('.imported', count: result.imported)
    end
  end

  private

  # From the Lanes tab, back to it with the origin still picked; from a location page, back there.
  def after_save_redirect(lane)
    if params[:return_to] == 'lanes'
      redirect_to freight_rules_path(tab: 'lanes', origin_id: lane.origin_location_id), notice: t('.saved')
    else
      redirect_back_or_to freight_rules_path(tab: 'lanes'), notice: t('.saved')
    end
  end

  def lane_params
    params.require(:freight_lane).permit(:origin_location_id, :destination_location_id, :standard_miles, :notes)
  end
end
