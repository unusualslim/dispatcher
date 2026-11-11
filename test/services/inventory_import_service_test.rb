require 'test_helper'

# PDI's Current Inventory report comes in two layouts: "Current Inventory Levels" (today's on hand) and
# "Summary for a Date Range" (on hand as of a past day), whose quantity and cost sit three columns further right.
class InventoryImportServiceTest < ActiveSupport::TestCase
  def service(rows)
    InventoryImportService.new('report.xls').tap do |s|
      s.define_singleton_method(:parse_spreadsheet) { rows }
    end
  end

  def row(values)
    Array.new(24).tap { |r| values.each { |i, v| r[i] = v } }
  end

  test 'current inventory levels: quantity in col 17, cost in col 19' do
    s = service([row(0 => 'For 10/18/2026'), row(0 => 'Report Format', 4 => 'Current Inventory Levels'),
                 row(0 => '110 / FPS-South'), row(0 => 'COMPONENTS'),
                 row(0 => '27501 / 275 GAL IBC TOTE', 17 => 52.0, 19 => 1040.0)])
    item = s.preview.sole
    assert_equal ['27501', 52.0, 20.0, '110'], [item.part_number, item.quantity, item.cost_per_unit, item.site_code]
    assert_equal Date.new(2026, 10, 18), s.report_date
  end

  test 'summary for a date range: ending quantity in col 20, cost in col 22, date from the range end' do
    s = service([row(0 => 'For 09/30/2026 Thru 09/30/2026'),
                 row(0 => 'Report Format', 4 => 'Summary for a Date Range', 10 => 'Report Type'),
                 row(0 => '110 / FPS-South'), row(0 => 'COMPONENTS'),
                 row(0 => '27501 / 275 GAL IBC TOTE', 5 => 'EA', 8 => 75.0, 14 => 4.0, 20 => 71.0, 22 => 13_173.7)])
    item = s.preview.sole
    assert_equal ['27501', 71.0, '110'], [item.part_number, item.quantity, item.site_code]
    assert_in_delta 185.545, item.cost_per_unit, 0.001
    assert_equal Date.new(2026, 9, 30), s.report_date
  end
end
