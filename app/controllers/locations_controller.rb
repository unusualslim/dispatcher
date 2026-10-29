require 'net/http'

class LocationsController < ApplicationController
  include ListNeighbors
  include CsvRoundTrip
  permission_area :sales, lookups: %i[search select2],
                          areas: { map: :dispatch, vehicles: :dispatch, dispatch_routes: :dispatch }
  before_action :set_location, only: %i[show edit update destroy]
  before_action :set_products, only: %i[new edit create update]

  def index
    @locations = Location.includes(:location_category)

    return unless params[:query].present?

    search_term = "%#{params[:query]}%"
    @locations = @locations.where(
      'company_name ILIKE ? OR city ILIKE ? OR state ILIKE ? OR address ILIKE ? OR zip ILIKE ? OR phone_number ILIKE ? OR pdi_site_code ILIKE ?',
      search_term, search_term, search_term, search_term, search_term, search_term, search_term
    )
  end

  SHOW_TABS = %w[orders products customers].freeze

  # Orders, products and customers sit in tabs; only the open tab is loaded, and each is paginated.
  def show
    @location = Location.find(params[:id])
    find_list_neighbors(@location, Location.order(:company_name, :id).pluck(:id))
    @tab = SHOW_TABS.include?(params[:tab]) ? params[:tab] : 'orders'
    @counts = { 'orders' => @location.customer_orders.count, 'products' => @location.location_products.count,
                'customers' => @location.customers.count }
    case @tab
    when 'orders'
      @orders = @location.customer_orders.includes(customer_order_products: :product)
                         .order(created_at: :desc).paginate(page: params[:page], per_page: 25)
    when 'products'
      @location_products = @location.location_products.includes(:product).left_joins(:product)
                                    .order('products.name').paginate(page: params[:page], per_page: 50)
    else
      @customers = @location.customers.order(:name).paginate(page: params[:page], per_page: 50)
    end
  end

  def new
    @location = Location.new
  end

  def edit
    @location = Location.find(params[:id])
  end

  def create
    @location = Location.new(location_params)

    respond_to do |format|
      if @location.save
        # Created from the order form: link it to the order's customer.
        if (customer = Customer.find_by(id: params[:customer_id]))
          CustomerLocation.find_or_create_by!(customer: customer, location: @location)
        end
        format.html { redirect_to location_url(@location), notice: 'Location was successfully created.' }
        format.json do
          render json: { id: @location.id, city_with_company: @location.city_with_company }, status: :created
        end
      else
        format.html { render :new, status: :unprocessable_entity }
        format.json { render json: @location.errors, status: :unprocessable_entity }
      end
    end
  end

  def update
    @location = Location.find(params[:id])

    if @location.update(location_params)
      respond_to do |format|
        format.html { redirect_to @location, notice: 'Location was successfully updated.' }
        format.json { render :show, status: :ok, location: @location }
      end
    else
      format.html { render :new, status: :unprocessable_entity }
      format.json { render json: @location.errors, status: :unprocessable_entity }
    end
  end

  def destroy
    @location = Location.find(params[:id])
    if @location.destroy
      redirect_to locations_path, notice: 'Location was successfully deleted.'
    else
      redirect_to locations_path, alert: 'Failed to delete location.'
    end
  end

  # Destination search for the order form's select2 picker.
  # With customer_id, that customer's locations are listed first (and are the
  # only results before anything is typed); other matches follow. Locations
  # can be shared by several customers, hence the CustomerLocation join.
  def search
    query    = params[:query].to_s.strip
    customer = Customer.find_by(id: params[:customer_id]) if params[:customer_id].present?

    scope = Location.where(location_category_id: 2)
    if query.present?
      scope = scope.where('city ILIKE :q OR company_name ILIKE :q', q: "%#{Location.sanitize_sql_like(query)}%")
    end

    own = customer ? scope.where(id: customer.locations.select(:id)).order(:company_name, :city).to_a : []
    others = query.present? ? scope.where.not(id: own.map(&:id)).order(:company_name, :city).limit(25).to_a : []

    option = ->(l) { { id: l.id, text: l.city_with_company } }
    results =
      if own.any? && others.any?
        [{ text: "Locations for #{customer.name}", children: own.map(&option) },
         { text: 'All locations', children: others.map(&option) }]
      elsif own.any?
        [{ text: "Locations for #{customer.name}", children: own.map(&option) }]
      else
        others.map(&option)
      end

    render json: { results: results, customer_location_ids: own.map(&:id) }
  end

  def map
    @locations = Location.includes(:location_category, :customer_orders)
                         .where.not(latitude: nil, longitude: nil)

    active_dispatches = Dispatch.where(status: 'Sent to Driver')
                                .includes(customer_orders: :location)

    origin_locations = Location.where.not(latitude: nil, longitude: nil)
                               .index_by(&:full_address_with_company)

    # Straight-line routes only — OSRM routing loaded async after page paint
    @dispatch_routes = active_dispatches.filter_map do |dispatch|
      origin = origin_locations[dispatch.origin]
      next unless origin

      dest = dispatch.customer_orders.map(&:location).find { |l| l&.latitude && l.longitude }
      next unless dest

      {
        id: dispatch.id,
        origin: { lat: origin.latitude, lng: origin.longitude, name: origin.company_name },
        destination: { lat: dest.latitude, lng: dest.longitude, name: dest.company_name },
        driver: dispatch.driver&.full_name,
        dispatch_date: dispatch.dispatch_date,
        route_coords: []
      }
    end

    respond_to do |format|
      format.html { render layout: false }
      format.json do
        render json: @locations.as_json(only: %i[id latitude longitude city company_name location_category_id],
                                        methods: [:has_active_order])
      end
    end
  end

  def vehicles
    render json: fetch_samsara_vehicles
  end

  def dispatch_routes
    active_dispatches = if params[:ids].present?
                          Dispatch.where(id: params[:ids])
                        else
                          Dispatch.where(status: 'Sent to Driver')
                        end
    active_dispatches = active_dispatches.includes(customer_orders: :location)

    origin_locations = Location.where.not(latitude: nil, longitude: nil)
                               .index_by(&:full_address_with_company)

    routes = active_dispatches.filter_map do |dispatch|
      origin = origin_locations[dispatch.origin]
      next unless origin

      dest = dispatch.customer_orders.map(&:location).find { |l| l&.latitude && l.longitude }
      next unless dest

      route_coords = fetch_osrm_route(origin.latitude, origin.longitude, dest.latitude, dest.longitude)

      {
        id: dispatch.id,
        route_coords: route_coords || []
      }
    end

    render json: routes
  end

  def toggle_status
    @location = Location.find(params[:id])
    @location.update(disabled: !@location.disabled)

    status = @location.disabled ? 'disabled' : 'enabled'
    redirect_to locations_path, notice: "Location was successfully #{status}."
  end

  def select2
    q = params[:q].to_s.strip

    # ✅ ALWAYS origins only
    scope = Location.where(location_category_id: 1)

    if q.present?
      pattern = "%#{q.downcase}%"
      scope = scope.where(
        'LOWER(company_name) LIKE :p OR LOWER(city) LIKE :p OR LOWER(state) LIKE :p OR LOWER(zip) LIKE :p',
        p: pattern
      )
    end

    locations = scope.order(company_name: :asc, city: :asc).limit(25)

    render json: {
      results: locations.map do |l|
        text = [
          l.company_name.presence,
          l.city.presence,
          l.state.presence
        ].compact.join(' - ').presence || "Location ##{l.id}"

        { id: l.id, text: text }
      end
    }
  end

  private

  def fetch_samsara_vehicles
    api_key = ENV.fetch('SAMSARA_API_KEY', nil)
    return [] if api_key.blank?

    uri = URI('https://api.samsara.com/fleet/vehicles/locations')
    request = Net::HTTP::Get.new(uri)
    request['Authorization'] = "Bearer #{api_key}"
    request['Accept'] = 'application/json'

    response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) { |http| http.request(request) }
    data = JSON.parse(response.body)

    data.fetch('data', []).filter_map do |v|
      loc = v['location']
      next unless loc&.dig('latitude') && loc.dig('longitude')

      {
        id: v['id'],
        name: v['name'],
        lat: loc['latitude'],
        lng: loc['longitude'],
        last_seen: loc['time']
      }
    end
  rescue StandardError
    []
  end

  def fetch_osrm_route(orig_lat, orig_lng, dest_lat, dest_lng)
    uri = URI("https://router.project-osrm.org/route/v1/driving/#{orig_lng},#{orig_lat};#{dest_lng},#{dest_lat}?overview=full&geometries=geojson")
    response = Net::HTTP.get(uri)
    data = JSON.parse(response)
    coords = data.dig('routes', 0, 'geometry', 'coordinates')
    # OSRM returns [lng, lat]; Leaflet expects [lat, lng]
    coords&.map { |c| [c[1], c[0]] }
  rescue StandardError
    nil
  end

  def location_params
    params.require(:location).permit(:city, :address, :location_category_id, :company_name, :phone_number, :state,
                                     :notes, :zip, :max_capacity, :uleage_90, :latitude, :longitude, :cutoff_percent, :marker_color, :pdi_site_code, product_ids: [], methods: [:has_active_order?])
  end

  def set_products
    @products = Product.selectable(@location&.product_ids).order(:name)
  end

  def set_location
    @location = Location.includes(:products).find(params[:id])
  end

  def csv_resource
    Location
  end

  def csv_columns
    [
      { attr: :id,           header: 'ID',           readonly: true  },
      { attr: :company_name, header: 'Name',         readonly: false },
      { attr: :address,      header: 'Address',      readonly: false },
      { attr: :city,         header: 'City',         readonly: false },
      { attr: :state,        header: 'State',        readonly: false },
      { attr: :zip,          header: 'Zip',          readonly: false },
      { attr: :phone_number, header: 'Phone',        readonly: false },
      { attr: :latitude,     header: 'Latitude',     readonly: false },
      { attr: :longitude,    header: 'Longitude',    readonly: false }
    ]
  end
end
