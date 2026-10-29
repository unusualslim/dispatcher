module Freight
  # Prices a dispatch's load for a carrier that prices per dispatch: the rate at the farthest stop's lane from the
  # origin × the load's gallons (or loads), then additional stops (every stop after the first) and fuel surcharge.
  # Returns { farthest:, stops:, gallons:, parts: [{ rule:, charge_type:, label:, quantity:, rate:, amount: }],
  # total: }, or nil when the carrier prices per order or something is missing (see #warnings).
  class LoadPricer
    Stop = Struct.new(:location, :miles, keyword_init: true)

    attr_reader :warnings

    def initialize(dispatch, orders, gallons)
      @dispatch = dispatch
      @orders = orders
      @gallons = gallons
      @warnings = []
    end

    def call
      return warn('No orders on this dispatch have products with a freight class.') if @gallons.empty?

      freight_rule = rule('freight')
      return unless freight_rule&.per_dispatch?
      return warn('Set the dispatch origin to price the load at the farthest stop.') unless origin

      farthest = farthest_stop
      base = farthest && base_part(freight_rule, farthest)
      base && summary(farthest, [base, extra_stops_part, surcharge_part(base[:amount])].compact)
    end

    private

    def summary(farthest, parts)
      { farthest: farthest, stops: stops.size, gallons: total_gallons, parts: parts, total: parts.sum do |p|
        p[:amount]
      end }
    end

    def origin = @dispatch.origin_location
    def total_gallons = @gallons.values.sum

    def primary_class
      @orders.flat_map(&:customer_order_products).filter_map { |l| l.product&.freight_class }
             .tally.max_by { |_, n| n }&.first
    end

    # The orders' carrier (PDI's carrier on the order, else the dispatch's), most common first.
    def carrier_id
      @orders.filter_map(&:freight_carrier_vendor_id).tally.max_by { |_, n| n }&.first
    end

    def rule(charge_type)
      FreightRule.best(side: 'purchase', charge_type: charge_type, date: @dispatch.dispatch_date || Date.current,
                       origin_id: origin&.id, freight_class_id: primary_class&.id, carrier_id: carrier_id)
    end

    def stops
      @stops ||= @gallons.keys.map(&:location).uniq.map do |location|
        Stop.new(location: location, miles: Miles.between(origin, location).first)
      end
    end

    def farthest_stop
      missing = stops.select { |s| s.miles.nil? }.map { |s| s.location.company_name }
      return warn("No miles for #{missing.to_sentence}: add a lane.") if missing.any?

      stops.max_by(&:miles)
    end

    def base_part(freight_rule, farthest)
      name = farthest.location.company_name
      row = freight_rule.freight_table.rate_for(origin_id: origin.id, destination_id: farthest.location.id,
                                                miles: farthest.miles)
      return warn("#{freight_rule.name}: no rate for #{name}.") unless row

      part(freight_rule, 'freight', load_quantity(freight_rule), row.rate,
           "Freight – farthest stop #{name}, #{farthest.miles.round} mi")
    end

    def load_quantity(freight_rule)
      case freight_rule.basis
      when 'per_load' then primary_class ? primary_class.loads_for(total_gallons) : 1
      when 'flat' then 1
      else total_gallons
      end
    end

    def extra_stops_part
      extra = stops.size - 1
      stop_rule = rule('extra_stop') if extra.positive?
      row = flat_rate(stop_rule)
      row && part(stop_rule, 'extra_stop', extra, row.rate, "Additional stops (#{extra})")
    end

    def surcharge_part(freight_amount)
      surcharge_rule = rule('fuel_surcharge')
      row = flat_rate(surcharge_rule) if surcharge_rule&.basis == 'percent'
      row && part(surcharge_rule, 'fuel_surcharge', freight_amount, row.rate / 100, 'Fuel surcharge')
    end

    def flat_rate(rule) = rule&.freight_table&.rate_for(origin_id: origin.id, destination_id: nil, miles: nil)

    # quantity × rate (a percent rate is passed as a fraction), never below the rule's minimum.
    def part(rule, charge_type, quantity, rate, label)
      amount = [quantity * rate, rule.minimum_amount || 0].max.round(2)
      { rule: rule, charge_type: charge_type, quantity: quantity, rate: rate, amount: amount, label: label }
    end

    def warn(message)
      @warnings << message
      nil
    end
  end
end
