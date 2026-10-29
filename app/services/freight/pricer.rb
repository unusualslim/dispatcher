module Freight
  # Turns one freight rule into one order charge: looks up the rate in the rule's table for the order (origin,
  # destination, miles) and multiplies by what the basis counts. Markup rules price off the purchase charges
  # already worked out. Problems (no rate, nothing to mark up) become warnings and no charge.
  class Pricer
    attr_reader :warnings

    def initialize(order)
      @order = order
      @warnings = []
    end

    # Volume: quantity (gallons), loads, count (stops / pump offs), base (freight for a percent), earlier (charges
    # already priced, for markups).
    def price(rule, freight_class: nil, earlier: [], **volume)
      return markup(rule, freight_class, earlier) if rule.markup?

      row = rate_row(rule)
      return warn(no_rate_message(rule)) unless row

      qty = basis_quantity(rule.basis, volume)
      qty && build(rule, freight_class, qty, row.rate, extend_amount(rule, qty, row.rate))
    end

    def warn(message)
      @warnings << message
      nil
    end

    private

    def rate_row(rule)
      rule.freight_table.rate_for(origin_id: @order.freight_origin&.id, destination_id: @order.location_id,
                                  miles: miles)
    end

    # Percent rates are a percent of the base; everything else is quantity × rate.
    def extend_amount(rule, qty, rate)
      rule.basis == 'percent' ? qty * rate / 100 : qty * rate
    end

    def basis_quantity(basis, volume)
      { 'per_unit' => volume[:quantity], 'per_load' => volume[:loads], 'per_stop' => volume[:count],
        'per_pump_off' => volume[:count], 'percent' => volume[:base], 'flat' => 1 }[basis]
    end

    # Sale = the purchase charges of the same type (and class) × (1 + markup %).
    def markup(rule, freight_class, earlier)
      cost = earlier.select { |c| marks_up?(c, rule, freight_class) }.sum(0.to_d, &:amount)
      unless cost.positive?
        return warn("#{rule.name}: marks up the carrier cost, but no purchase #{rule.charge_label.downcase} was found.")
      end

      build(rule, freight_class, cost, rule.markup_percent, cost * (1 + (rule.markup_percent / 100)))
    end

    def marks_up?(charge, rule, freight_class)
      charge.side == 'purchase' && charge.charge_type == rule.charge_type &&
        (freight_class.nil? || charge.freight_class == freight_class)
    end

    def build(rule, freight_class, qty, rate, amount)
      amount = [amount, rule.minimum_amount].max if rule.minimum_amount
      OrderFreightCharge.new(side: rule.side, charge_type: rule.charge_type, freight_rule: rule, basis: rule.basis,
                             freight_class: freight_class, carrier_id: carrier_for(rule.side), quantity: qty,
                             rate: rate, amount: amount.round(2), description: description(rule, freight_class))
    end

    def description(rule, freight_class)
      [rule.charge_label, freight_class && "Class #{freight_class.code}"].compact.join(' – ')
    end

    # Purchase charges are owed to the order's carrier (when it's a vendor in the app).
    def carrier_for(side)
      return unless side == 'purchase'

      @carrier_id ||= Vendor.where(id: @order.freight_carrier_vendor_id).pick(:id) || false
      @carrier_id || nil
    end

    def no_rate_message(rule)
      detail = rule.freight_table.lookup_type == 'mileage' && miles.nil? ? ' (no miles: enter them on the order)' : ''
      "#{rule.name}: #{rule.freight_table.name} has no rate for this order#{detail}."
    end

    def miles
      return @miles if defined?(@miles)

      @miles = @order.freight_miles_or_estimate
    end
  end
end
