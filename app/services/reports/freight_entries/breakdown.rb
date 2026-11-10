module Reports
  module FreightEntries
    # Splits a fuel line's per-gallon "Freight" item into PDI's freight in detail (PdiFreightComponent): base rate,
    # FPLFSC, TAFSC… Purchase lines use the load components, sale lines the order components, matched by order and
    # product (and BOL when both have one). Components the load / order already carries as a charge of their own
    # (OWIFSC, FPLSPLIT…) are skipped. Whatever the components don't explain (total freight overrides, lines from
    # before PDI kept detail) stays a "Freight" line, so totals never change; a difference under TOLERANCE (rounding)
    # goes on the largest component instead. Lines whose components come to more than the line are left whole.
    class Breakdown
      TOLERANCE = BigDecimal('0.05')

      def initialize(order_nos)
        rows = PdiFreightComponent.where(order_no: order_nos.compact.uniq).order(:rule_type, :charge, :id)
        @loads, @orders = rows.partition(&:load?).map { |list| list.group_by { |c| [c.order_no, c.product] } }
      end

      # raw: a stored freight item with 'side'. existing: charge names already on the load / order for that side.
      def split(raw, order_no, existing)
        return [raw] unless raw['charge'] == PdiOrders::TruckFreight::LINE_FREIGHT && raw['amount'].to_d.positive?

        parts = components(raw, order_no).reject { |c| existing.include?(c.charge) }
        parts.empty? ? [raw] : divide(raw, parts)
      end

      private

      def components(raw, order_no)
        return @orders.fetch([order_no, raw['product']], []).select(&:sale) unless raw['side'] == 'purchase'

        list = @loads.fetch([order_no, raw['product']], []).select(&:purchase)
        raw['bol'] ? list.select { |c| c.bol.nil? || c.bol == raw['bol'] } : list
      end

      def divide(raw, parts)
        rest = raw['amount'].to_d - parts.sum(&:amount)
        return [raw] if rest < -TOLERANCE
        return parts.map { |c| part(raw, c) } + [rest_part(raw, rest)] if rest >= TOLERANCE

        rounded(raw, parts, rest)
      end

      # A rounding difference goes on the largest component.
      def rounded(raw, parts, rest)
        biggest = parts.max_by(&:amount)
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
