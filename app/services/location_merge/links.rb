class LocationMerge
  # Customer links (customer_locations) during a location merge. A customer linked to both keeps one
  # link, carrying the source's PDI ship-to ID when the target's has none. A customer whose links are two
  # different PDI ship-tos can't be merged: one location holds one ship-to per customer.
  class Links
    def initialize(source, target)
      @source = source
      @target = target
    end

    # The source link that would collide with a different PDI ship-to on the target, if any.
    def ship_to_clash
      @source.customer_locations.includes(:customer).find do |link|
        other = target_links[link.customer_id]
        other && link.pdi_location_id.present? && other.pdi_location_id.present? &&
          other.pdi_location_id != link.pdi_location_id
      end
    end

    def apply!
      @source.customer_locations.each do |link|
        other = target_links[link.customer_id]
        next link.update!(location: @target) unless other

        pdi_location_id = link.pdi_location_id
        link.destroy!
        other.update!(pdi_location_id: pdi_location_id) if other.pdi_location_id.blank? && pdi_location_id.present?
      end
    end

    private

    def target_links
      @target_links ||= @target.customer_locations.index_by(&:customer_id)
    end
  end
end
