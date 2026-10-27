# Month-to-date financial and operating figures, compared with the same days of the prior month and of
# the same month last year. Flows (sales, delivery time, production…) are per period (Sales, Operations);
# point-in-time figures (open orders, inventory value…) are in Snapshot.
class FinancialDashboard
  PERIODS = { current: 'This period', prior_month: 'Prior month', last_year: 'Last year' }.freeze

  attr_reader :month, :today

  def initialize(month: Date.current.beginning_of_month, today: Date.current)
    @month = month.beginning_of_month
    @today = today
  end

  # { current: range, prior_month: range, last_year: range }, each covering the same days of its month.
  def ranges
    @ranges ||= begin
      last = [today, month.end_of_month].min
      days = (last - month).to_i
      { current: month..last, prior_month: same_days(month.prev_month, days),
        last_year: same_days(month.prev_year, days) }
    end
  end

  def sales
    @sales ||= ranges.transform_values { |range| Sales.new(range) }
  end

  def operations
    @operations ||= ranges.transform_values { |range| Operations.new(range) }
  end

  def snapshot
    @snapshot ||= Snapshot.new
  end

  def month_to_date?
    ranges[:current].end < month.end_of_month
  end

  private

  def same_days(start, days)
    start..[start + days, start.end_of_month].min
  end
end
