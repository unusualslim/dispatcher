require 'roo'

class MinMaxImportService
  SHEET_NAME = 'MASTER Product List'

  COL_PART_ID = 0
  COL_MIN     = 4
  COL_MAX     = 5

  SKIP_PATTERNS = /Part#|PHYSICAL|RAW MATERIAL|FINISHED/i

  Result = Struct.new(:updated, :skipped_no_product, :skipped_no_values, :errors, keyword_init: true)

  def self.call(path)
    new(path).run
  end

  def initialize(path)
    @path = path
  end

  def run
    result = Result.new(updated: 0, skipped_no_product: 0, skipped_no_values: 0, errors: [])

    wb = Roo::Excelx.new(@path)
    wb.sheet(SHEET_NAME)

    (1..wb.last_row).each do |i|
      row = wb.row(i)
      part_id = row[COL_PART_ID].to_s.strip
      next if part_id.blank? || part_id.match?(SKIP_PATTERNS)

      min_val = row[COL_MIN]
      max_val = row[COL_MAX]

      if min_val.nil? && max_val.nil?
        result.skipped_no_values += 1
        next
      end

      product = Product.find_by(id: part_id)
      unless product
        result.skipped_no_product += 1
        result.errors << "#{part_id} not found in LoadNTrucks — skipped"
        next
      end

      product.update!(
        reorder_point: min_val.present? ? min_val.to_f : product.reorder_point,
        max_stock:     max_val.present? ? max_val.to_f : product.max_stock
      )
      result.updated += 1
    rescue => e
      result.errors << "Row #{i} (#{part_id}): #{e.message}"
    end

    result
  end
end
