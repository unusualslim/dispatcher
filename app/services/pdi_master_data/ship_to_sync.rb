module PdiMasterData
  # PDI ship-tos (nested under each customer) → customer_locations.pdi_location_id.
  # A new ship-to is linked to one of the customer's existing locations with the same name, else to a
  # destination location with the same name + address + zip (so the FPS warehouse pickup stays one
  # location), else a location is created. Existing locations are never renamed, because the FTP order
  # import still finds locations by name; only their blank address fields are filled in.
  class ShipToSync < Sync
    SECTION = :ship_tos

    ShipTo = Struct.new(:pdi_customer_id, :customer, :id, :name, :label, :attrs, :active, keyword_init: true) do
      def key
        "#{pdi_customer_id}-#{id}"
      end

      def location_attrs
        attrs.merge(company_name: name)
      end

      def new_location
        Location.new(location_attrs.merge(location_category_id: 2))
      end
    end

    def call
      linked = CustomerLocation.where.not(pdi_location_id: nil)
      @links = linked.includes(:location).index_by { |link| [link.customer_id, link.pdi_location_id] }
      @link_counts = linked.group(:location_id).count
      @by_address = Location.where(location_category_id: 2).group_by { |l| place_key(l) }
      @taken = {}
      customer_nodes.each { |node| sync_customer(node) }
    end

    private

    def sync_customer(customer_node)
      customer_id = text(customer_node, 'ID')
      return unless customers.key?(customer_id)

      customer_node.xpath('CustomerLocation').each do |node|
        ship_to = build_ship_to(customer_id, node)
        guard(ship_to.key, ship_to.label) { sync(ship_to) }
      end
    end

    def build_ship_to(customer_id, node)
      name = text(node, 'Description')
      ShipTo.new(pdi_customer_id: customer_id, customer: customers[customer_id], id: text(node, 'ID'), name: name,
                 label: [name, text(node, 'City')].compact.join(', '), attrs: location_attrs(node),
                 active: text(node, 'Active') != '0')
    end

    def location_attrs(node)
      { address: text(node, 'Address1'), city: text(node, 'City'), state: text(node, 'StateProvinceID'),
        zip: text(node, 'PostalCode'), phone_number: text(node, 'Phone') }.compact
    end

    def sync(ship_to)
      link = ship_to.customer && @links[[ship_to.customer.id, ship_to.id]]
      return update(ship_to, link.location) if link
      return record(:skip, ship_to.key, ship_to.label, {}, 'Inactive in PDI') unless ship_to.active

      location = existing_location(ship_to)
      location ? link_existing(ship_to, location) : create(ship_to)
    end

    # A location shared by several PDI ship-tos keeps its own details.
    def update(ship_to, location)
      shared = @link_counts[location.id].to_i > 1
      changes = shared ? {} : diff(location, ship_to.location_attrs)
      location.update!(changes) if apply? && changes.any?
      record(changes.any? ? :update : :unchanged, ship_to.key, ship_to.label, changes)
    end

    def link_existing(ship_to, location)
      blanks = ship_to.attrs.select { |field, value| location[field].blank? && value.present? }
      if apply?
        location.update!(blanks) if blanks.any?
        link(ship_to, location)
      end
      taken(ship_to) << location
      record(:link, ship_to.key, ship_to.label, blanks, "Matched #{location.company_name}")
    end

    def create(ship_to)
      location = ship_to.new_location
      if apply?
        location.save!
        link(ship_to, location)
      end
      # Later ship-tos at the same place share it (a preview shares the unsaved record).
      (@by_address[place_key(location)] ||= []) << location
      taken(ship_to) << location
      record(:create, ship_to.key, ship_to.label, ship_to.location_attrs)
    end

    def link(ship_to, location)
      CustomerLocation.find_or_initialize_by(customer: ship_to.customer, location: location)
                      .update!(pdi_location_id: ship_to.id)
      @link_counts[location.id] = @link_counts[location.id].to_i + 1
    end

    # Never a location already serving another of the customer's ship-tos.
    def existing_location(ship_to)
      same_place = Array(@by_address[place_key(ship_to.new_location)])
      (same_name_locations(ship_to) + same_place).find { |location| taken(ship_to).none? { |t| same?(t, location) } }
    end

    # The customer's own locations (from its orders) not yet linked to a PDI ship-to, by name.
    def same_name_locations(ship_to)
      return [] unless ship_to.customer

      name = normalize(ship_to.name)
      CustomerLocation.where(customer: ship_to.customer, pdi_location_id: nil).includes(:location)
                      .map(&:location).select { |l| normalize(l.company_name) == name }
    end

    # Locations already serving one of this PDI customer's ship-tos (saved, or unsaved in a preview).
    def taken(ship_to)
      @taken[ship_to.pdi_customer_id] ||=
        if ship_to.customer
          Location.joins(:customer_locations).where(customer_locations: { customer_id: ship_to.customer.id })
                  .where.not(customer_locations: { pdi_location_id: nil }).to_a
        else
          []
        end
    end

    def same?(one, other)
      one.equal?(other) || (one.id.present? && one.id == other.id)
    end
  end
end
