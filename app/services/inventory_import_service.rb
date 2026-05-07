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
      product     = Product.find_by(id: part_number)

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
          id:              row.part_number,
          name:            row.description,
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

    Rails.logger.info "[InventoryImport] last_row=#{sheet.last_row}"
    sample_done = false

    (2..sheet.last_row).each do |i|
      row = sheet.row(i)
      r1  = row[1]

      # Log full row structure for first section so we can see column layout
      unless sample_done
        if r1.to_s.start_with?('COMPONENTS')
          sample_done = true
          (-1..5).each do |offset|
            idx = i + offset
            next unless idx >= 2
            sample_row = sheet.row(idx)
            non_nil = sample_row.each_with_index.reject { |v, _| v.nil? }.map { |v, j| "#{j}:#{v.inspect}" }
            Rails.logger.info "[InventoryImport] SAMPLE row #{idx}: [#{non_nil.join(', ')}]"
          end
        end
      end

      # Skip header/footer rows (date cells, legend row)
      next if r1.to_s =~ /\d{4}-\d{2}-\d{2}/ || r1.to_s.start_with?('Exception Legend')
      rows << row
    end

    Rails.logger.info "[InventoryImport] parsed #{rows.size} data rows"
    rows
  end

  def parse_quantity(val)
    return nil if val.blank?
    Float(val.to_s.gsub(/,/, '')) rescue nil
  end
end
