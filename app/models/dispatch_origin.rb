# Finds the origin terminal for a dispatch's origin text. The text is a snapshot of the location's
# "Company - address city, state zip" when the dispatch was saved, so a location renamed or re-addressed since no
# longer matches exactly: then the terminal in the same city (or zip) whose street address shares the most words
# with the text wins. Very old dispatches stored just the city.
module DispatchOrigin
  module_function

  def resolve(text, terminals = Location.where(location_category_id: 1).to_a)
    return if text.blank?

    terminals.find { |l| l.full_address_with_company == text } || by_address(text, terminals) ||
      terminals.find { |l| l.city.present? && l.city.casecmp?(text.strip) }
  end

  def by_address(text, terminals)
    rest = text.split(' - ', 2).last.downcase
    scored = terminals.filter_map do |location|
      next unless same_place?(location, rest)

      overlap = (words(location.address) & words(rest)).size
      [overlap, location] if overlap.positive?
    end
    scored.max_by(&:first)&.last
  end

  def same_place?(location, rest)
    (location.city.present? && rest.include?(location.city.downcase)) ||
      (location.zip.present? && rest.include?(location.zip.to_s))
  end

  # Street words of two or more characters ("10154", "highway", "fountain").
  def words(text) = text.to_s.downcase.scan(/[a-z0-9]+/).select { |w| w.size > 1 }
end
