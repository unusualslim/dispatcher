module PdiOrders
  # The customer and delivery location for a PDI order, found by the PDI IDs that the PDI Master Data
  # import links (customers.pdi_customer_id, customer_locations.pdi_location_id). A customer or ship-to
  # added in PDI since the last master data run is linked here: by name, by the location the order
  # already has (FTP import), by name + zip, or created.
  class Destination
    # current: the location the order already has, if it was imported before.
    def initialize(order, current: nil)
      @order = order
      @current = current
    end

    def customer
      return if @order.site?

      @customer ||= Customer.find_by(pdi_customer_id: @order.customer_id) || link_customer || create_customer
    end

    def location
      @order.site? ? site_location : ship_to_location
    end

    private

    def link_customer
      match = Customer.where(pdi_customer_id: nil).find_by('LOWER(name) = ?', @order.customer_name.to_s.downcase)
      match&.tap { |c| c.update!(pdi_customer_id: @order.customer_id) }
    end

    def create_customer
      Customer.create!(name: @order.customer_name || "PDI customer #{@order.customer_id}",
                       pdi_customer_id: @order.customer_id, preferred_contact_method: 'no preference')
    end

    def ship_to_location
      return unlinked_location unless @order.ship_to_id

      linked = CustomerLocation.find_by(customer: customer, pdi_location_id: @order.ship_to_id)&.location
      return linked if linked

      unlinked_location.tap do |location|
        CustomerLocation.find_or_initialize_by(customer: customer, location: location)
                        .update!(pdi_location_id: @order.ship_to_id)
      end
    end

    # Never a location already serving another of this customer's PDI ship-tos.
    def unlinked_location
      taken = CustomerLocation.where(customer: customer).where.not(pdi_location_id: nil).pluck(:location_id)
      return @current if @current && taken.exclude?(@current.id)

      same_place(taken) || new_location
    end

    def same_place(taken)
      Location.where(location_category_id: 2).where.not(id: taken)
              .where('LOWER(TRIM(company_name)) = ? AND LEFT(zip, 5) = ?', ship_to_name.downcase, zip5).order(:id).first
    end

    # Our own sites (tank wagon, bulk plants) by PDI site number, then by name.
    def site_location
      Location.find_by(pdi_site_code: [@order.site_id, @order.site_id.to_s.rjust(4, '0')].compact_blank) ||
        Location.find_by(company_name: ship_to_name) || new_location
    end

    def new_location
      Location.create!(@order.ship_to.merge(company_name: ship_to_name, location_category_id: 2))
    end

    def ship_to_name
      @order.ship_to[:company_name] || "PDI #{@order.site? ? 'site' : 'ship-to'} #{@order.site_id || @order.ship_to_id}"
    end

    def zip5
      @order.ship_to[:zip].to_s[0, 5]
    end
  end
end
