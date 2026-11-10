require 'csv'

module PdiFreightComponents
  # Loads the PDI freight detail export (docs/pdi_sql/freight_detail.sql): CSV with a header row, columns by name.
  # Each line in the file (source + line key) has its components replaced, so a rule PDI removed drops out too.
  class Import
    REQUIRED = %w[source component_key line_key rule_name amount].freeze
    TEXT = ->(value) { value }
    WHOLE = ->(value) { value.sub(/\.0+\z/, '') } # keys and IDs that went through a float: "34779.0"
    FLAG = ->(value) { value.downcase.in?(%w[-1 1 true]) } # PDI booleans: -1 = true
    # header => [column, conversion]
    COLUMNS = {
      'component_key' => [:component_key, TEXT], 'load_no' => [:load_no, WHOLE],
      'load_reference_no' => [:load_reference_no, TEXT], 'business_date' => [:business_date, ->(v) { Date.parse(v) }],
      'order_no' => [:order_no, TEXT], 'bol' => [:bol, TEXT], 'product_id' => [:product, WHOLE],
      'line_key' => [:line_key, WHOLE], 'line_freight' => [:line_freight, :to_d.to_proc],
      'rule_name' => [:charge, TEXT],
      'rule_type' => [:rule_type, :to_i.to_proc], 'purchase' => [:purchase, FLAG], 'sale' => [:sale, FLAG],
      'method' => [:method, TEXT], 'basis' => [:basis, :to_d.to_proc], 'rate' => [:rate, :to_d.to_proc],
      'amount' => [:amount, ->(v) { v.to_d.round(2) }]
    }.freeze
    BATCH = 1000

    Result = Struct.new(:created, :skipped, :warnings, keyword_init: true)

    def self.call(path) = new(path).run

    def initialize(path)
      @path = path
      @skipped = 0
      @charges = 0
    end

    def run
      rows = read
      PdiFreightComponent.transaction { replace(rows) }
      Result.new(created: rows.size, skipped: @skipped + @charges, warnings: warnings(rows))
    end

    private

    def replace(rows)
      rows.group_by { |row| row[:source] }.each do |source, list|
        PdiFreightComponent.where(source: source, line_key: list.pluck(:line_key).uniq).delete_all
      end
      rows.each_slice(BATCH) { |slice| PdiFreightComponent.insert_all!(slice) } # rubocop:disable Rails/SkipsModelValidations
    end

    def read
      table = CSV.read(@path, headers: true, encoding: 'bom|utf-8')
      headers = headers(table)
      now = Time.current
      rows = table.filter_map { |raw| row(headers.zip(raw.fields.map { |v| v.to_s.strip.presence }).to_h, now) }
      rows.uniq { |row| row.values_at(:source, :component_key) }
    end

    def headers(table)
      headers = table.headers.map { |header| header.to_s.strip.downcase }
      missing = REQUIRED - headers
      raise ArgumentError, "Missing columns #{missing.join(', ')} in: #{table.headers.join(', ')}" if missing.any?

      headers
    end

    def row(values, now)
      source = values['source'].to_s.downcase
      return skip(values) unless PdiFreightComponent::SOURCES.include?(source) && values.values_at(*REQUIRED).all?

      fields = COLUMNS.to_h { |header, (column, convert)| [column, values[header] && convert.call(values[header])] }
      fields.merge(source: source, purchase: fields[:purchase] || false, sale: fields[:sale] || false,
                   created_at: now, updated_at: now)
    end

    # Order / load level charges (OWIFSC, PER LOAD OWI…) have no fuel line; the API sends those.
    def skip(values)
      values['line_key'].nil? && values['rule_name'] ? @charges += 1 : @skipped += 1
      nil
    end

    def warnings(rows)
      loads = rows.filter_map { |row| row[:load_no] if row[:source] == 'load' }.uniq
      missing = loads - PdiFuelLoad.where(load_no: loads).pluck(:load_no)
      [missing.any? && "#{missing.size} loads not in the app yet (e.g. #{missing.first(5).join(', ')})",
       @charges.positive? && "#{@charges} order/load-level charges left to the API",
       @skipped.positive? && "#{@skipped} rows without source, key, rule or amount"].select(&:itself)
    end
  end
end
