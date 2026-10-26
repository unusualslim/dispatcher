class LocationMerge
  # How sure we are that two of a customer's locations are the same place, 0–100, with the reasons.
  # One customer, the same street address and the same zip / city is 90, and any name evidence (same
  # name, store number, a shared name word) makes it 100; those 95+ pairs are pre-selected. Otherwise
  # it's name (≤ 50) + place (≤ 50): a same-name pair with no address on one side tops out at 85.
  class Confidence
    GENERIC_WORDS = %w[the inc llc co company corp and of travel center centers store site].freeze
    # [area, one has no address] => points, reason
    PLACE_POINTS = { [:zip, true] => [35, 'same zip, one has no address'],
                     [:zip, false] => [15, 'same zip'],
                     [:city, true] => [25, 'same city, one has no address'],
                     [:city, false] => [10, 'same city'] }.freeze

    attr_reader :score, :reasons

    # keep_link / remove_link: the customer's links (customer_locations) to the two locations.
    def initialize(keep_link, remove_link)
      @keep_link = keep_link
      @keep = keep_link.location
      @remove = remove_link.location
      @reasons = []
      @score = (same_street? && area ? street_score : name_score + place_score).clamp(0, 100)
    end

    def self.street(location) = location.address.to_s.downcase.gsub(/[^a-z0-9]/, '')
    def self.zip5(location) = location.zip.to_s.strip[0, 5].presence
    def self.city(location) = location.city.to_s.strip.downcase
    def self.squashed_name(location) = location.company_name.to_s.sub(/\A\d+\s*-\s*/, '').downcase.gsub(/[^a-z0-9]/, '')

    def self.name_words(location)
      location.company_name.to_s.downcase.scan(/[a-z]{2,}/) - GENERIC_WORDS
    end

    private

    def street_score
      reason(90, 'same street address') + (name_score.positive? ? 10 : 0)
    end

    def same_street?
      streets.all?(&:present?) && streets.uniq.size == 1
    end

    def name_score
      if self.class.squashed_name(@keep) == self.class.squashed_name(@remove)
        reason(50, 'same name')
      elsif store_number?
        reason(45, "store number = PDI ship-to #{@keep_link.pdi_location_id}")
      else
        shared_words
      end
    end

    def store_number?
      @keep_link.pdi_location_id.present? && @remove.company_name.to_s.scan(/\d+/).include?(@keep_link.pdi_location_id)
    end

    def shared_words
      share = word_share
      share.positive? ? reason((45 * share).round, "#{(share * 100).round}% of name words shared") : 0
    end

    def word_share
      mine = self.class.name_words(@keep)
      theirs = self.class.name_words(@remove)
      union = (mine | theirs).size
      union.zero? ? 0 : (mine & theirs).size.to_f / union
    end

    def place_score
      return 0 unless area

      reason(*PLACE_POINTS[[area, streets.any?(&:blank?)]])
    end

    def streets
      @streets ||= [@keep, @remove].map { |l| self.class.street(l) }
    end

    def area
      return :zip if same_zip?

      :city if same_city?
    end

    def same_zip?
      zip = self.class.zip5(@keep)
      zip.present? && zip == self.class.zip5(@remove)
    end

    def same_city?
      city = self.class.city(@keep)
      city.present? && city == self.class.city(@remove)
    end

    def reason(points, text)
      @reasons << text
      points
    end
  end
end
