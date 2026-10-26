class CustomerMerge
  # The source's delivery locations during a merge. The FTP order import named them "35 - Quik Trip
  # Warehouse" (35 = PDI ship-to number), and store chains are often named by store number ("146
  # Cartersville TA", "TA #201"), which is also PDI's ship-to number. When the target already has that
  # PDI ship-to (a location the master data import created or linked), the two are folded together:
  # the source's location is kept (it has the history), takes the PDI link and any blank address
  # fields, the target's orders there move to it, and the other copy is deleted if nothing else uses
  # it. Other locations simply move to the target.
  class LocationPairs
    Pair = Struct.new(:old_link, :new_link, keyword_init: true) do
      def old_location = old_link.location
      def new_location = new_link.location
    end

    ADDRESS = %i[address city state zip phone_number].freeze

    def initialize(source, target)
      @source = source
      @target = target
    end

    def pairs
      @pairs ||= begin
        taken = []
        source_links.filter_map do |link|
          match = ship_to_for(link, taken)
          taken << match if match
          Pair.new(old_link: link, new_link: match) if match
        end
      end
    end

    # The target's PDI ship-to link this source location duplicates, if any. A location that already is
    # one of the target's ship-tos stays as it is.
    def ship_to_for(link, taken)
      return if target_ship_to_location_ids.include?(link.location_id)

      target_links.find { |t| taken.exclude?(t) && same_ship_to?(link.location, t) }
    end

    # Source locations that aren't folded into a PDI ship-to and simply move over.
    def moving
      source_links - pairs.map(&:old_link)
    end

    def apply!
      pairs.each { |pair| fold(pair) }
      moving.each do |link|
        if CustomerLocation.exists?(customer: @target, location_id: link.location_id)
          link.destroy!
        else
          link.update!(customer: @target)
        end
      end
    end

    # Whether the import's copy can go once its link points at the old location.
    def deletable?(location)
      references(location).zero?
    end

    private

    def source_links
      @source_links ||= @source.customer_locations.includes(:location).to_a
    end

    def target_links
      @target_links ||= @target.customer_locations.where.not(pdi_location_id: nil).includes(:location).to_a
    end

    def target_ship_to_location_ids
      @target_ship_to_location_ids ||= target_links.map(&:location_id)
    end

    def same_ship_to?(location, target_link)
      return false if location.id == target_link.location_id

      name = location.company_name.to_s
      leading = name[/\A\s*#?(\d+)(?:\s*-|\s)/, 1]
      return leading == target_link.pdi_location_id if leading
      return true if numbered_in_same_city?(location, target_link)

      normalize(name) == normalize(target_link.location.company_name)
    end

    # "TA 238 Columbia Petro" / "TA #201": a number later in the name counts only in the same city.
    def numbered_in_same_city?(location, target_link)
      location.company_name.to_s.scan(/\d+/).include?(target_link.pdi_location_id) &&
        location.city.to_s.strip.casecmp?(target_link.location.city.to_s.strip)
    end

    def normalize(name)
      name.to_s.sub(/\A\d+\s*-\s*/, '').downcase.gsub(/[^a-z0-9]+/, ' ').squish
    end

    def fold(pair)
      old_location = pair.old_location
      new_location = pair.new_location
      fill_blanks(old_location, new_location)
      CustomerOrder.where(customer_id: @target.id, location_id: new_location.id)
                   .update_all(location_id: old_location.id) # rubocop:disable Rails/SkipsModelValidations
      pair.old_link.destroy!
      # The target's own plain link to the kept location (e.g. from its orders) gives way to the ship-to link.
      CustomerLocation.where(customer: @target, location: old_location, pdi_location_id: nil).destroy_all
      pair.new_link.update!(location: old_location)
      new_location.destroy! if deletable?(new_location)
    end

    def fill_blanks(old_location, new_location)
      blanks = ADDRESS.index_with { |f| new_location[f] }.select { |f, v| v.present? && old_location[f].blank? }
      old_location.update!(blanks) if blanks.any?
    end

    # Rows that still point at a location (anything but zero keeps it).
    LOCATION_ID_MODELS = [CustomerLocation, CustomerOrder, CustomerOrderProduct, InventoryTransaction, LocationContact,
                          LocationProduct, ProductionOrder, PurchaseOrder, Quote].freeze

    def references(location)
      LOCATION_ID_MODELS.sum { |model| model.where(location_id: location.id).count } +
        Dispatch.where(destination_location_id: location.id).count + WorkOrder.where(workable: location).count +
        legacy_product_links(location)
    end

    # The old locations_products join table has no model.
    def legacy_product_links(location)
      ActiveRecord::Base.connection.select_value(
        "SELECT COUNT(*) FROM locations_products WHERE location_id = #{location.id.to_i}"
      ).to_i
    end
  end
end
