module PdiOrders
  # PDI only re-sends an order to this web partner once it changes, so open app orders that weren't in
  # this run's feed are asked for their status one at a time (GetOrderStatus doesn't use up the feed).
  class StatusCheck
    LIMIT = 200 # per run; least recently checked first, so a long list is covered over several runs
    NOT_FOUND = 99

    Result = Struct.new(:checked, :updated, :not_found, :errors, keyword_init: true)

    def initialize(client, skip: [])
      @client = client
      @skip = skip.to_a
    end

    def run
      result = Result.new(checked: 0, updated: 0, not_found: 0, errors: [])
      candidates.each do |order|
        result.checked += 1
        outcome = refresh(order)
        result[outcome] += 1 if outcome
      rescue *PdiWebService::FAILURES, ArgumentError => e
        result.errors << "#{order.external_order_no}: #{e.message}"
      end
      result
    end

    private

    def candidates
      CustomerOrder.where(order_status: CustomerOrder::ACTIVE_STATUSES).where.not(external_order_no: [nil, ''])
                   .where.not(external_order_no: @skip).order(:updated_at).limit(LIMIT)
    end

    def refresh(order)
      code = @client.order_status(order.external_order_no)
      order.touch # rubocop:disable Rails/SkipsModelValidations -- only moves it to the back of the queue
      return :not_found if code.nil? || code == NOT_FOUND
      return if order.order_status == Statuses.enum_key(code)

      order.update!(order_status: Statuses.enum_key(code), odor_status: Statuses.name(code))
      :updated
    end
  end
end
