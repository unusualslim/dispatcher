module Reports
  # The filters a report offers (its filter_names) read from request params: a date range plus optional
  # customer, product, warehouse, vendor, item type, movement type and a "problems only" switch.
  class Filters
    SELECTS = %i[customer_id product_id location_id vendor_id item_type movement_type].freeze

    attr_reader :names, :from, :to, :values

    def initialize(params, report_class, today)
      @names = report_class.filter_names
      @from = date(params[:from]) || report_class.default_from(today)
      @to = date(params[:to]) || today
      @values = SELECTS.index_with { |key| params[key].presence }
      @values[:only_problems] = params.key?(:only_problems) ? params[:only_problems] == '1' : true
    end

    def range
      [from, to].min..[from, to].max
    end

    delegate :[], to: :values

    def only_problems?
      values[:only_problems]
    end

    def offers?(name)
      names.include?(name)
    end

    # The current filters as query params (for the CSV link and the form).
    def to_params
      { from: from.iso8601, to: to.iso8601, only_problems: (only_problems? ? '1' : '0') }
        .merge(values.slice(*SELECTS).compact)
    end

    private

    def date(value)
      Date.iso8601(value.to_s) if value.present?
    rescue Date::Error
      nil
    end
  end
end
