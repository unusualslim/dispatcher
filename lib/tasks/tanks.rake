require 'csv'

namespace :tanks do
  # Converts the dispatcher's TankOnHandDaysInv.xlsx into the CSV that Data Imports → Tank Feeds (Spreadsheet
  # history) takes. Run on a Mac/PC with the workbook; the 22 MB file is too big to parse in a web request.
  #   bin/rails "tanks:spreadsheet_csv[tmp/TankOnHandDaysInv.xlsx,tmp/tank_history.csv]"
  # Each tab holds 10-row blocks per day: date, 90% ullage, 6AM inventory … day load, night load. Only typed
  # 6AM inventories are readings (formulas are the sheet's projections), and only blocks for the tab's current
  # site and product (the tabs were reused for other sites in earlier years).
  desc 'Convert TankOnHandDaysInv.xlsx to a tank history CSV'
  task :spreadsheet_csv, %i[xlsx out] => :environment do |_t, args|
    book = Roo::Excelx.new(args.fetch(:xlsx))
    out = args[:out].presence || 'tmp/tank_history.csv'
    count = 0
    CSV.open(out, 'w') do |csv|
      csv << %w[tab site date fill_limit gallons day_load night_load]
      book.sheets.each do |tab|
        rows = TankSpreadsheetTab.new(book.sheet(tab), tab).rows
        rows.each { |row| csv << row }
        count += rows.size
        puts "#{tab}: #{rows.size} readings (#{rows.first&.at(2)} – #{rows.last&.at(2)})"
      end
    end
    puts "#{count} readings written to #{out}"
  end
end

# One tab of TankOnHandDaysInv.xlsx.
class TankSpreadsheetTab
  BLOCK = 10

  def initialize(sheet, tab)
    @sheet = sheet
    @tab = tab
  end

  # Readings for the tab's current site and product, as CSV rows.
  def rows
    blocks = (1..@sheet.last_row).step(BLOCK).filter_map { |top| block(top) }.select { |b| b[:gallons] }
    return [] if blocks.empty?

    current = blocks.last.values_at(:site, :product)
    blocks.select { |b| b.values_at(:site, :product) == current }.map { |b| csv_row(b) }
  end

  private

  def csv_row(block)
    [@tab, block[:site], block[:date].iso8601, *block.values_at(:fill_limit, :gallons, :day_load, :night_load)]
  end

  def block(top)
    date = @sheet.cell(top, 1)
    return unless date.is_a?(Date)

    { date: date.to_date, product: text(top, 4), site: text(top + 3, 1), fill_limit: value(top + 1),
      gallons: typed(top + 2), day_load: typed(top + 6), night_load: typed(top + 7) }
  end

  def text(row, column)
    @sheet.cell(row, column).to_s.strip
  end

  def value(row)
    number = @sheet.cell(row, 4)
    number.round(2) if number.is_a?(Numeric)
  end

  # Typed numbers only; a formula is a projection, not a reading.
  def typed(row)
    value(row) unless @sheet.formula(row, 4)
  end
end
