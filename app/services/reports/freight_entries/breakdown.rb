module Reports
  module FreightEntries
    # Splits a fuel line's per-gallon "Freight" item into PDI's freight in detail (PdiFreightComponent): base rate,
    # FPLFSC, TAFSC… Purchase lines use the load components, sale lines the order components. An item is matched to
    # one PDI line by order and product (and BOL on loads); when several lines share those, by the line's freight
    # total. Purchase lines take purchase-side rules plus a Total Freight Override (flagged neither side, it replaces
    # the rules); sale lines the sale-side rules. Rules the load / order already carries as a charge of their own
    # (OWIFSC, FPLSPLIT…) are skipped. Whatever the components don't explain stays a "Freight" line, so totals never
    # change; a difference under TOLERANCE (rounding) goes on the largest component instead. Lines whose components
    # come to more than the line are left whole.
    class Breakdown
      TOLERANCE = BigDecimal('0.05')

      def initialize(order_nos)
        rows = PdiFreightComponent.where(order_no: order_nos.compact.uniq).order(:rule_type, :charge, :id)
        @lines = rows.group_by { |c| [c.source, c.order_no, c.product] }
                     .transform_values { |list| list.group_by(&:line_key).values }
        @used = Set.new
      end

      # raw: a stored freight item with 'side'. existing: charge names already on the load / order for that side.
      def split(raw, order_no, existing)
        return [raw] unless raw['charge'] == PdiOrders::TruckFreight::LINE_FREIGHT && raw['amount'].to_d.nonzero?

        parts = Array(line(raw, order_no)).select { |c| applies?(c, raw['side']) }
                                          .reject { |c| existing.include?(c.charge) }
        parts.empty? ? [raw] : divide(raw, parts)
      end

      private

      # The components of the PDI line this item is, each PDI line used once.
      def line(raw, order_no)
        lines = candidates(raw, order_no)
        found = lines.find { |list| close?(list.first.line_freight, raw['amount'].to_d) } || (lines.first if lines.one?)
        @used << found.first.line_key if found
        found
      end

      def candidates(raw, order_no)
        source = raw['side'] == 'purchase' ? 'load' : 'order'
        @lines.fetch([source, order_no, raw['product']], []).select do |list|
          first = list.first
          @used.exclude?(first.line_key) && (raw['bol'].nil? || first.bol.nil? || first.bol == raw['bol'])
        end
      end

      def close?(total, amount) = total && (total - amount).abs < TOLERANCE

      def applies?(component, side)
        side == 'purchase' ? component.purchase || component.override? : component.sale
      end

      # Credits (corrections) split the same way, signs reversed.
      def divide(raw, parts)
        amount = raw['amount'].to_d
        rest = amount - parts.sum(&:amount)
        left = amount.negative? ? -rest : rest
        return [raw] if left < -TOLERANCE
        return parts.map { |c| part(raw, c) } + [rest_part(raw, rest)] if left >= TOLERANCE

        rounded(raw, parts, rest)
      end

      # A rounding difference goes on the largest component.
      def rounded(raw, parts, rest)
        biggest = parts.max_by { |c| c.amount.abs }
        parts.map { |c| part(raw, c, c.equal?(biggest) ? rest : 0) }
      end

      def part(raw, component, extra = 0)
        raw.merge('charge' => component.charge, 'rate' => component.rate&.to_s('F'),
                  'amount' => (component.amount + extra).to_s('F'), 'base' => component.base?)
      end

      def rest_part(raw, rest) = raw.merge('rate' => nil, 'amount' => rest.to_s('F'), 'base' => true)
    end
  end
end
