require 'csv'

module Reports
  # A report: filters in, rows out. Subclasses set the metadata, list their columns and build #rows (hashes
  # keyed by column); the hub, table, totals, CSV and print come from ReportsController and its views.
  class Base
    # format: :currency, :price (4 decimals), :number, :decimal, :percent (a share, 0–1), :days, :date or :text.
    # total: summed in the totals row.
    Column = Struct.new(:key, :label, :format, :total, keyword_init: true)

    class << self
      attr_reader :title, :area, :description, :filter_names

      def key
        name.demodulize.underscore
      end

      # area: the permission area that can see it (sales, dispatch, production, purchasing, inventory, accounting).
      def report(title:, area:, description:, filters: [:dates])
        @title = title
        @area = area.to_s
        @description = description
        @filter_names = filters
      end

      # Where the date range starts when none is chosen (this month unless a report says otherwise).
      def default_from(today)
        today.beginning_of_month
      end
    end

    attr_reader :filters

    def initialize(params = {}, today: Date.current)
      @filters = Filters.new(params, self.class, today)
    end

    def columns
      raise NotImplementedError
    end

    def rows
      raise NotImplementedError
    end

    def totals
      @totals ||= columns.select(&:total).to_h { |column| [column.key, rows.sum { |row| row[column.key].to_d }] }
    end

    # Columns, rows and a totals line, values unformatted.
    def to_csv
      CSV.generate do |csv|
        csv << columns.map(&:label)
        rows.each { |row| csv << columns.map { |column| row[column.key] } }
        csv << totals_line if totals.any?
      end
    end

    # A link for one cell (e.g. the order number), or nil.
    def link_for(_row, _column)
      nil
    end

    private

    def totals_line
      columns.map.with_index { |column, i| i.zero? ? 'Total' : totals[column.key] }
    end

    # [[group, *sums]] for SQL aggregate expressions.
    def sums_by(scope, group, sums)
      scope.group(group).pluck(group, *sums.map { |sql| Arel.sql(sql) })
    end

    def column(key, label, format = :text, total: false)
      Column.new(key: key, label: label, format: format, total: total)
    end

    def range
      filters.range
    end

    def time_range
      range.begin.beginning_of_day..range.end.end_of_day
    end
  end
end
