class InventoryImportService
  # Columns in the PDI warehouse inventory export (WIWI / Fishbowl format)
  # Row example: ["COMPONENTS", "1014111", "275 TOTE DIP TUBE", nil, 55, nil, 1093.04, nil]
  COL_CATEGORY    = 0
  COL_PART_NUMBER = 1
  COL_DESCRIPTION = 2
  COL_QUANTITY    = 4

  # Categories that are not inventory product lines (skip these rows)
  SKIP_PREFIXES = [].freeze

  ImportRow = Struct.new(:part_number, :description, :category, :quantity,
                         :product, :action, keyword_init: true)

  def initialize(file)
    @file = file
  end

  # Returns an array of ImportRow structs — does NOT write to DB.
  # action: :update (matched product), :create (no match), :skip (bad row)
  def preview
    rows = []
    parse_xlsx.each do |raw|
      qty = parse_quantity(raw[COL_QUANTITY])
      next if qty.nil?

      part_number = raw[COL_PART_NUMBER].to_s.strip
      description = raw[COL_DESCRIPTION].to_s.strip
      category    = raw[COL_CATEGORY].to_s.strip
      next if part_number.blank? || description.blank?
      product     = Product.find_by(part_number: part_number)

      rows << ImportRow.new(
        part_number: part_number,
        description: description,
        category:    category,
        quantity:    qty,
        product:     product,
        action:      product ? :update : :create
      )
    end
    rows
  end

  # Applies the import. Returns { updated: N, created: N, skipped: N }
  def import(selected_part_numbers: nil, product_type: "raw_material")
    rows    = preview
    counts  = { updated: 0, created: 0, skipped: 0 }
    is_raw  = product_type != "finished_good"

    rows.each do |row|
      if selected_part_numbers && !selected_part_numbers.include?(row.part_number)
        counts[:skipped] += 1
        next
      end

      case row.action
      when :update
        row.product.update!(current_stock: row.quantity)
        counts[:updated] += 1
      when :create
        Product.create!(
          name:            row.description,
          part_number:     row.part_number,
          current_stock:   row.quantity,
          is_raw_material: is_raw
        )
        counts[:created] += 1
      end
    end

    counts
  end

  private

  def parse_xlsx
    xlsx  = Roo::Spreadsheet.open(@file.path, extension: :xlsx)
    sheet = xlsx.sheet(0)
    rows  = []

    (2..sheet.last_row).each do |i|
      row = sheet.row(i)
      # Stop at footer rows (date/time metadata row or legend row)
      break if row[1].to_s =~ /\d{4}-\d{2}-\d{2}/ || row[1].to_s.start_with?('Exception Legend')
      rows << row
    end

    rows
  end

  def parse_quantity(val)
    return nil if val.blank?
    Float(val.to_s.gsub(/,/, '')) rescue nil
  end
end
