module Mrp
  # Nets one product's events against its stock, day by day. When the balance (counting earlier
  # suggestions) drops below safety stock, it suggests supply for the shortfall on that date: production
  # (products with a BOM) starting production_days earlier, which adds component demand on the start date,
  # or a purchase to order lead_days earlier. Lot-for-lot: no minimums or batching yet.
  class ProductPlan
    Row = Struct.new(:event, :balance, keyword_init: true)
    Suggestion = Struct.new(:kind, :qty, :need_date, :act_by, keyword_init: true) do
      def late?(today) = act_by < today
      def production? = kind == :planned_production
    end

    attr_reader :product, :rows, :suggestions, :runs_out_on, :below_safety_on, :lead_days, :today

    # lead_days: production days for a product with a BOM, else its purchase lead time.
    def initialize(product, events, bom:, lead_days:, today:)
      @product = product
      @events = events
      @bom = bom
      @lead_days = lead_days
      @today = today
      @rows = []
      @suggestions = []
    end

    def on_hand = product.current_stock.to_d
    def safety = product.safety_stock.to_d
    def manufactured? = @bom.any?

    def net!
      @firm = @balance = on_hand
      sorted_events.each { |event| step(event) }
      self
    end

    # Demand that this product's suggested production puts on its components: [[component ID, Event]].
    def component_demand
      @suggestions.select(&:production?).flat_map do |suggestion|
        @bom.map do |component_id, per_unit|
          [component_id, Event.new(date: [suggestion.act_by, today].max, qty: -(suggestion.qty * per_unit),
                                   kind: :planned_component, label: "Planned production of #{product.name}",
                                   flags: [])]
        end
      end
    end

    # Firm supply arriving after the product has run out: worth expediting.
    def expedite
      return [] unless runs_out_on

      @rows.map(&:event).select { |e| e.supply? && !e.planned? && e.date > runs_out_on }
    end

    # The demand up to the first shortage: why it runs out.
    def causes
      return [] unless shortage_date

      @rows.map(&:event).select { |e| !e.supply? && e.date <= shortage_date }.sort_by(&:qty).first(3)
    end

    # When it first falls short: runs out, else drops below safety stock, else needs a suggestion.
    def shortage_date
      runs_out_on || below_safety_on || @suggestions.first&.need_date
    end

    def first_action_date = @suggestions.map(&:act_by).min

    private

    def sorted_events
      @events.sort_by { |e| [e.date, e.supply? ? 0 : 1] }
    end

    # Firm events (and demand from parents' suggested production) move both balances; suggested supply
    # only the planned one. Short of safety stock after
    # a demand: suggest supply for the difference.
    def step(event)
      @balance += event.qty
      @rows << Row.new(event: event, balance: @balance)
      track_firm(event) unless event.planned? && event.supply? # suggested supply isn't real yet
      @balance += suggest(event.date, safety - @balance) if event.qty.negative? && @balance < safety
    end

    def track_firm(event)
      @firm += event.qty
      @runs_out_on ||= event.date if @firm.negative?
      @below_safety_on ||= event.date if safety.positive? && @firm < safety
    end

    def suggest(date, qty)
      kind = manufactured? ? :planned_production : :planned_purchase
      suggestion = Suggestion.new(kind: kind, qty: qty, need_date: date, act_by: date - lead_days)
      @suggestions << suggestion
      @rows << Row.new(event: Event.new(date: date, qty: qty, kind: kind, label: suggestion_label(suggestion),
                                        flags: []), balance: @balance + qty)
      qty
    end

    def suggestion_label(suggestion)
      verb = suggestion.production? ? 'Start production' : 'Order'
      "Suggested: #{verb} by #{suggestion.act_by.strftime('%b %-d')} (#{lead_days}-day lead time)"
    end
  end
end
