module Mrp
  # Nets one product's events at one warehouse against that warehouse's stock, day by day. When the
  # balance (counting earlier suggestions) drops below safety stock, it suggests supply for the shortfall
  # on that date: production (products with a BOM) starting lead_days earlier, which adds component
  # demand on the start date, or a purchase to order lead_days earlier. Mrp::Transfers may then add
  # suggested transfers between warehouses and re-net. Lot-for-lot: no minimums or batching yet.
  class ProductPlan
    Row = Struct.new(:event, :balance, keyword_init: true)
    Suggestion = Struct.new(:kind, :qty, :need_date, :act_by, keyword_init: true) do
      def late?(today) = act_by < today
      def production? = kind == :planned_production
    end
    # bom: [[component ID, qty per unit]]; lead_days: production days with a BOM, else the purchase
    # lead time; on_hand: stock at this warehouse; safety: safety stock held here.
    Setup = Struct.new(:bom, :lead_days, :on_hand, :safety, :location, keyword_init: true)

    attr_reader :product, :rows, :suggestions, :runs_out_on, :below_safety_on, :today

    def initialize(product, events, setup, today:)
      @product = product
      @events = events.dup
      @setup = setup
      @today = today
    end

    def on_hand = @setup.on_hand.to_d
    def safety = @setup.safety.to_d
    def lead_days = @setup.lead_days
    def location = @setup.location
    def location_id = location&.id
    def manufactured? = @setup.bom.any?

    def add_event(event)
      @events << event
    end

    def net!
      @rows = []
      @suggestions = []
      @runs_out_on = @below_safety_on = nil
      @firm = @balance = on_hand
      sorted_events.each { |event| step(event) }
      self
    end

    # Demand that this product's suggested production puts on its components here: [[component ID, Event]].
    def component_demand
      @suggestions.select(&:production?).flat_map do |suggestion|
        @setup.bom.map do |component_id, per_unit|
          [component_id, Event.new(date: [suggestion.act_by, today].max, qty: -(suggestion.qty * per_unit),
                                   kind: :planned_component, label: "Planned production of #{product.name}",
                                   flags: [], location_id: location_id)]
        end
      end
    end

    # Suggested transfers into this warehouse.
    def transfers_in = @rows.map(&:event).select { |e| e.kind == :planned_transfer_in }
    def needs_action? = @suggestions.any? || transfers_in.any?

    # Firm supply arriving after the product has run out: worth expediting.
    def expedite
      return [] unless runs_out_on

      @rows.map(&:event).select { |e| e.supply? && !e.planned? && e.date > runs_out_on }
    end

    # The demand up to the first shortage: why it runs out.
    def causes
      return [] unless shortage_date

      @rows.map(&:event).select { |e| !e.supply? && !e.transfer? && e.date <= shortage_date }.sort_by(&:qty).first(3)
    end

    # When it first falls short: runs out, else drops below safety stock, else needs a suggestion.
    def shortage_date
      runs_out_on || below_safety_on || @suggestions.first&.need_date || transfers_in.first&.date
    end

    def first_action_date
      (@suggestions.map(&:act_by) + transfers_in.map { |e| e.date - 1 }).min
    end

    # Stock this warehouse can give up from date on: its lowest projected balance from then, above safety.
    def spare_from(date)
      before = @rows.reverse.find { |row| row.event.date < date }&.balance || on_hand
      ([before] + @rows.select { |row| row.event.date >= date }.map(&:balance)).min - safety
    end

    private

    def sorted_events
      @events.sort_by { |e| [e.date, e.supply? ? 0 : 1] }
    end

    def step(event)
      @balance += event.qty
      @rows << Row.new(event: event, balance: @balance)
      track_firm(event) unless event.planned? && event.supply? # suggested supply isn't real yet
      @balance += suggest(event.date, safety - @balance) if event.qty.negative? && @balance < safety
    end

    # Firm events (and demand from parents' suggested production) move the firm balance.
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
                                        flags: [], location_id: location_id), balance: @balance + qty)
      qty
    end

    def suggestion_label(suggestion)
      verb = suggestion.production? ? 'Start production' : 'Order'
      "Suggested: #{verb} by #{suggestion.act_by.strftime('%b %-d')} (#{lead_days}-day lead time)"
    end
  end
end
