module Mrp
  # Before buying or producing for a warehouse that runs short, moves spare stock from the product's
  # other warehouses: spare = a warehouse's lowest projected balance from the move on, above its safety
  # stock. Each move adds a planned transfer out (donor, transfer_days before the need) and in (receiver,
  # on the need date), and both re-net, so the receiver's order shrinks by what arrives.
  class Transfers
    MAX_MOVES = 25

    def initialize(plans, today:, transfer_days:)
      @plans = plans
      @today = today
      @transfer_days = transfer_days
    end

    def apply!
      MAX_MOVES.times { break unless move_one }
      @plans
    end

    private

    def move_one
      @plans.each do |receiver|
        receiver.suggestions.each do |suggestion|
          donor, spare = best_donor(receiver, ship_date(suggestion))
          next unless donor

          transfer(donor, receiver, [spare, suggestion.qty].min, suggestion.need_date)
          return true
        end
      end
      false
    end

    def best_donor(receiver, date)
      @plans.reject { |plan| plan.equal?(receiver) }
            .map { |plan| [plan, plan.spare_from(date)] }.select { |_, spare| spare.positive? }
            .max_by { |_, spare| spare }
    end

    def ship_date(suggestion)
      [suggestion.need_date - @transfer_days, @today].max
    end

    def transfer(donor, receiver, qty, need_date)
      ship = [need_date - @transfer_days, @today].max
      donor.add_event(event(ship, -qty, :planned_transfer_out, "Suggested: transfer to #{name(receiver)} " \
                                                               "by #{ship.strftime('%b %-d')}", donor))
      receiver.add_event(event(need_date, qty, :planned_transfer_in, "Suggested: transfer from #{name(donor)} " \
                                                                     "by #{ship.strftime('%b %-d')}", receiver))
      donor.net!
      receiver.net!
    end

    def event(date, qty, kind, label, plan)
      Event.new(date: date, qty: qty, kind: kind, label: label, flags: [], location_id: plan.location_id)
    end

    def name(plan) = plan.location&.company_name || 'unassigned'
  end
end
