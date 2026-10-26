class CustomerMerge
  # Likely PDI customers for app customers the master data import couldn't link, ranked by shared name
  # words. "Cummins Business ServicesOrder" and "Cimarron Lumber … Date/Time: 01/21/2026" (FTP import
  # leftovers) are cleaned first. Only suggestions: an admin picks the match on the merge page.
  class Suggestions
    STOP_WORDS = %w[inc llc co company corp corporation the of and ltd cod nad].freeze
    MIN_SCORE = 0.5

    Match = Struct.new(:customer, :score)

    def initialize(candidates = Customer.where.not(pdi_customer_id: nil))
      @candidates = candidates.map { |c| [c, words(c.name)] }
    end

    # Best few matches for one customer, best first.
    def for(customer, limit: 3)
      mine = words(customer.name)
      return [] if mine.empty?

      @candidates.filter_map { |candidate, theirs| match(candidate, mine, theirs) }
                 .sort_by { |m| [-m.score, m.customer.name] }.first(limit)
    end

    def words(name)
      cleaned = name.to_s.sub(%r{date/time:.*\z}i, '').sub(/order\s*\z/i, '').downcase.gsub('&', ' and ')
      cleaned.gsub(/[^a-z0-9]+/, ' ').split - STOP_WORDS
    end

    private

    # Share of this customer's words found in the candidate's, nudged by how much of the candidate matched.
    def match(candidate, mine, theirs)
      shared = (mine & theirs).size
      return if shared.zero?

      score = (shared.to_f / mine.size) + (0.1 * shared / theirs.size)
      Match.new(candidate, score.round(2)) if score >= MIN_SCORE
    end
  end
end
