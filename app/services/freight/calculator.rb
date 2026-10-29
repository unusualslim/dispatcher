module Freight
  # Works out an order's freight from the rules. For each side (purchase = carrier cost, then sale = customer
  # charge) and each freight class on the order: base freight (per gallon or per load), then the accessorials:
  # fuel surcharge (percent of that side's freight), additional stops and pump offs. Lines without a freight class
  # (warehouse goods) get manual charges instead.
  #
  #   result = Freight::Calculator.new(order).call  # => #<Result charges=[...] warnings=[...]>
  #   Freight::Calculator.new(order).apply!          # replaces the order's calculated charges, syncs payables
  class Calculator
    Result = Struct.new(:charges, :warnings, keyword_init: true)
    SIDES = %w[purchase sale].freeze
    ACCESSORIALS = { 'extra_stop' => :freight_extra_stops, 'pump_off' => :freight_pump_offs }.freeze

    attr_reader :order

    def initialize(order)
      @order = order
      @pricer = Pricer.new(order)
    end

    def call
      charges = sides.each_with_object([]) do |side, all|
        side_charges = class_groups.filter_map { |freight_class, qty| base_freight(side, freight_class, qty, all) }
        all.concat(side_charges + accessorials(side, side_charges.sum(&:amount), all))
      end
      @pricer.warn('No products on this order have a freight class, so nothing was calculated.') if class_groups.empty?
      Result.new(charges: charges, warnings: @pricer.warnings.uniq)
    end

    # A carrier that prices per dispatch (farthest stop) sets the carrier cost from the dispatch, not here.
    def dispatch_priced?
      return @dispatch_priced if defined?(@dispatch_priced)

      @dispatch_priced = (class_groups.any? && find_rule('purchase', 'freight', primary_class)&.per_dispatch?) || false
    end

    # Replaces the calculated charges (manual ones stay) and refreshes the carrier payables.
    def apply!
      result = call
      order.transaction do
        replace_calculated!(result.charges)
        OrderPayables.sync!(order)
      end
      result
    end

    private

    def sides = dispatch_priced? ? SIDES - ['purchase'] : SIDES

    def replace_calculated!(charges)
      order.order_freight_charges.where(calculated: true, dispatch_id: nil).delete_all
      charges.each { |charge| charge.update!(customer_order: order, calculated: true) }
      order.update!(freight_calculated_at: Time.current)
      order.order_freight_charges.reset
    end

    # { FreightClass => quantity } over the order's lines whose product has a class.
    def class_groups
      @class_groups ||= classed_lines.group_by { |line| line.product.freight_class }
                                     .transform_values { |lines| lines.sum { |l| line_quantity(l) } }
                                     .select { |_, qty| qty.positive? }
    end

    def classed_lines
      order.customer_order_products.includes(product: :freight_class).select { |line| line.product&.freight_class }
    end

    # What shipped, else what was ordered.
    def line_quantity(line) = (line.shipped_quantity || line.quantity).to_d

    def primary_class = class_groups.max_by { |_, qty| qty }&.first

    # Order-level quantity and loads, for accessorials priced per gallon or per load.
    def order_volume
      { quantity: class_groups.values.sum, loads: class_groups.sum { |fc, qty| fc.loads_for(qty) } }
    end

    def base_freight(side, freight_class, qty, earlier)
      rule = find_rule(side, 'freight', freight_class)
      return missing(side, 'freight', freight_class) unless rule

      @pricer.price(rule, freight_class: freight_class, quantity: qty, loads: freight_class.loads_for(qty),
                          earlier: earlier)
    end

    def accessorials(side, freight_total, earlier)
      return [] if class_groups.empty?

      charges = ACCESSORIALS.map { |charge_type, count_attr| per_count(side, charge_type, count_attr, earlier) }
      [fuel_surcharge(side, freight_total, earlier), *charges].compact
    end

    # Additional stops / pump offs: the order's count × the rule's rate.
    def per_count(side, charge_type, count_attr, earlier)
      count = order.public_send(count_attr).to_i
      return unless count.positive?

      rule = find_rule(side, charge_type, primary_class)
      return missing(side, charge_type, primary_class) unless rule

      @pricer.price(rule, count: count, **order_volume, earlier: earlier)
    end

    def fuel_surcharge(side, freight_total, earlier)
      rule = find_rule(side, 'fuel_surcharge', primary_class)
      return unless rule && freight_total.positive?

      @pricer.price(rule, base: freight_total, count: 1, **order_volume, earlier: earlier)
    end

    def find_rule(side, charge_type, freight_class)
      FreightRule.best(side: side, charge_type: charge_type, date: order_date, origin_id: order.freight_origin&.id,
                       freight_class_id: freight_class&.id, carrier_id: order.freight_carrier_vendor_id,
                       customer_id: order.customer_id)
    end

    def missing(side, charge_type, freight_class)
      class_text = freight_class ? " for class #{freight_class.code}" : ''
      label = FreightRule::CHARGE_TYPES[charge_type].downcase
      @pricer.warn("No #{side} #{label} rule matches this order#{class_text}.")
    end

    def order_date
      (order.order_date || order.required_delivery_date || order.created_at || Time.current).to_date
    end
  end
end
