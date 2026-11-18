module PdiOrders
  # PDI order numbers for orders sent from the app: OD-090001-26 … OD-099999-26, the next free one in the year's
  # range (PDI's own numbers are far below 090000 and roll to -27 in 2027, as does this range). Callers hold the
  # lock while they send, so two sends never get the same number.
  module OrderNumbers
    FIRST = 90_001
    LAST = 99_999
    LOCK_KEY = 4_270_901 # pg advisory lock id for Send to PDI numbering

    class RangeFull < StandardError; end

    module_function

    def next_for(date = Time.zone.today)
      year = format('%02d', date.year % 100)
      used = CustomerOrder.where('pdi_order_number LIKE ?', "OD-09____-#{year}").pluck(:pdi_order_number)
                          .map { |number| number[3, 6].to_i }.max
      sequence = used ? used + 1 : FIRST
      raise RangeFull, "All app order numbers for 20#{year} are used (OD-099999-#{year})" if sequence > LAST

      format('OD-%<n>06d-%<y>s', n: sequence, y: year)
    end

    # Runs the block inside a transaction holding the numbering lock.
    def with_lock(&)
      CustomerOrder.transaction do
        CustomerOrder.connection.execute("SELECT pg_advisory_xact_lock(#{LOCK_KEY})")
        yield
      end
    end
  end
end
