# Admin → Samsara: how dispatches become Samsara routes. Drivers link to Samsara drivers and get a home base
# (where their routes start and end); locations link to Samsara addresses automatically when first routed.
class SamsaraSettingsController < ApplicationController
  before_action :require_admin!

  TIME_FORMAT = /\A([01]?\d|2[0-3]):[0-5]\d\z/

  def edit
    @drivers = User.active.where(role: 'worker').order(:first_name, :last_name)
    @home_options = Location.where(location_category_id: 1)
                            .or(Location.where(show_in_warehouse_dropdown: true))
                            .or(Location.where(id: @drivers.filter_map(&:home_location_id)))
                            .order(:company_name)
    @linked_locations = Location.where.not(samsara_address_id: nil).order(:company_name)
    load_samsara
  end

  def update
    start_time = params[:samsara_route_start_time].to_s.strip
    return redirect_to edit_samsara_settings_path, alert: t('.invalid_time') unless start_time.match?(TIME_FORMAT)

    save_settings(start_time)
    redirect_to edit_samsara_settings_path, notice: t('.updated')
  end

  def unlink_location
    location = Location.find(params[:location_id])
    location.update!(samsara_address_id: nil)
    redirect_to edit_samsara_settings_path, notice: t('.unlinked', name: location.company_name)
  end

  private

  def save_settings(start_time)
    AppSetting.set('samsara_route_start_time', start_time)
    AppSetting.set('samsara_home_location_id', params[:samsara_home_location_id].presence)
    (params[:drivers] || {}).each do |id, attrs|
      User.where(role: 'worker').find(id).update!(samsara_driver_id: attrs[:samsara_driver_id].presence,
                                                  home_location_id: attrs[:home_location_id].presence)
    end
  end

  # Samsara's drivers and addresses, for the pickers and to name linked records. The page still works without them.
  def load_samsara
    links = Samsara::Links.new
    @samsara_drivers = links.drivers.sort_by { |d| d['name'].to_s }
    @samsara_addresses = links.addresses.index_by { |a| a['id'] }
  rescue *Samsara::Client::FAILURES => e
    @samsara_error = e.message
    @samsara_drivers = []
    @samsara_addresses = {}
  end
end
