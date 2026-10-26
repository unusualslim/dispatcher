class LocationMerge
  # Likely duplicate delivery locations: two of one customer's locations at the same zip / city that also
  # share a street address, a distinctive name word, or have no address on one side. (An account like
  # Five Points Recode serves many unrelated businesses in one town; zip / city alone would flag them all.)
  # Each pair suggests keeping the one with the customer's PDI ship-to link, else the one with more orders.
  # Pairs that are two different PDI ship-tos (a merge would be refused) are left out. Each carries a
  # Confidence score; most confident first.
  class Suggestions
    Pair = Struct.new(:customer, :keep, :remove, :score, :reasons, keyword_init: true)
    AUTO_SELECT = 95

    def pairs
      links = CustomerLocation.joins(:location).where(locations: { location_category_id: 2 })
                              .includes(:customer, :location).group_by(&:customer)
      links.flat_map { |customer, customer_links| pairs_for(customer, customer_links) }
           .sort_by { |pair| [-pair.score, pair.customer.name.to_s, pair.keep.company_name.to_s] }
    end

    private

    def pairs_for(customer, links)
      links.combination(2).filter_map do |a, b|
        next unless candidate?(a, b)

        keep, remove = keeper_first(a, b)
        confidence = Confidence.new(keep, remove)
        Pair.new(customer: customer, keep: keep.location, remove: remove.location, score: confidence.score,
                 reasons: confidence.reasons)
      end
    end

    # Same place, alike, and not two different PDI ship-tos (that merge would be refused).
    def candidate?(one, other)
      return false if one.pdi_location_id.present? && other.pdi_location_id.present?

      same_place?(one.location, other.location) && alike?(one.location, other.location)
    end

    def keeper_first(*links)
      links.sort_by { |link| [link.pdi_location_id.present? ? 0 : 1, -orders(link.location_id)] }
    end

    # Same 5-digit zip, or same city when one of them has no zip (so a customer's several sites in
    # one big city aren't all flagged).
    def same_place?(one, other)
      return zip5(one) == zip5(other) if zip5(one) && zip5(other)

      city(one).present? && city(one) == city(other)
    end

    def alike?(one, other)
      return true if one.address.blank? || other.address.blank? || street(one) == street(other)

      name_words(one).intersect?(name_words(other))
    end

    def street(location) = Confidence.street(location)
    def name_words(location) = Confidence.name_words(location)
    def zip5(location) = Confidence.zip5(location)
    def city(location) = Confidence.city(location)

    def orders(location_id)
      @orders ||= CustomerOrder.group(:location_id).count
      @orders[location_id].to_i
    end
  end
end
