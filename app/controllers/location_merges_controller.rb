# Admin → Merge Locations: folds duplicate locations (same place, two records) together with a preview
# first (LocationMerge).
class LocationMergesController < ApplicationController
  before_action :require_admin!

  # Likely duplicates: two of one customer's locations at the same zip / city.
  def index
    @pairs = LocationMerge::Suggestions.new.pairs
    @order_counts = CustomerOrder.where(location_id: @pairs.flat_map { |p| [p.keep.id, p.remove.id] })
                                 .group(:location_id).count
  end

  # source_id = the location to remove; with target_id (the one to keep), preview the merge.
  def new
    @source = Location.find(params[:source_id])
    @target = Location.find_by(id: params[:target_id])
    @merge = LocationMerge.new(@source, @target) if @target
  rescue ArgumentError => e
    @error = e.message
  end

  def create
    merge = build_merge
    notice = merged_notice(merge) # counted before the records move
    merge.merge!
    redirect_to after_merge_path(merge.target), notice: notice
  rescue ArgumentError, ActiveRecord::ActiveRecordError => e
    log_failure(e)
    redirect_to location_merges_path, alert: t('.failed', error: e.message)
  end

  # Location search for the keep picker.
  def targets
    term = params[:q].to_s.strip
    locations = Location.order(:company_name).limit(25)
    if term.present?
      locations = locations.where('company_name ILIKE :q OR city ILIKE :q OR address ILIKE :q', q: "%#{term}%")
    end
    render json: locations.map { |l| { id: l.id, text: label(l) } }
  end

  private

  def build_merge
    LocationMerge.new(Location.find(params[:source_id]), Location.find(params[:target_id]))
  end

  # Back to the kept location when the merge started from a location's page.
  def after_merge_path(target)
    params[:return_to] == 'location' ? location_path(target) : location_merges_path
  end

  def log_failure(error)
    Rails.logger.warn "[LocationMerge] #{params[:source_id]} → #{params[:target_id]} failed: " \
                      "#{error.class}: #{error.message}"
  end

  def merged_notice(merge)
    t('location_merges.create.merged', source: merge.source.company_name, target: merge.target.company_name,
                                       summary: merge.summary.presence || t('location_merges.create.nothing_moved'))
  end

  def label(location)
    [location.company_name, [location.address, location.city, location.state].compact_blank.join(', ').presence]
      .compact.join(' — ')
  end
end
