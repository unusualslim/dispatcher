class InventoryImportService
  # PDI warehouse inventory export format (WIWI / Fishbowl)
  # Col 0: "PART_NUMBER / DESCRIPTION" for product rows, or category name for section headers
  # Col 17: on-hand quantity
  COL_COMBINED = 0
  COL_QUANTITY = 17

  ImportRow = Struct.new(:part_number, :description, :category, :quantity,
                         :product, :action, keyword_init: true)

  def initialize(file)
    @file = file
  end

  # Returns an array of ImportRow structs — does NOT write to DB.
  # action: :update (matched product), :create (no match)
  def preview
    rows = []
    current_category = nil

    parse_xlsx.each do |raw|
      combined = raw[COL_COMBINED].to_s.strip
      next if combined.blank?

      # Section header rows (e.g. "COMPONENTS-BOTTLES") have no " / " separator
      unless combined.include?(' / ')
        current_category = combined unless combined.start_with?('Total for')
        next
      end

      part_number, description = combined.split(' / ', 2)
      part_number = part_number.to_s.strip
      description = description.to_s.strip
      next if part_number.blank? || description.blank?

      qty = parse_quantity(raw[COL_QUANTITY])
      next if qty.nil?

      product = Product.find_by(id: part_number)

      rows << ImportRow.new(
        part_number: part_number,
        description: description,
        category:    current_category.to_s,
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

    (2..sheet.last_row).each do |i|
      rows << sheet.row(i)
    end

    rows
  end

  def parse_quantity(val)
    return nil if val.blank?
    Float(val.to_s.gsub(/,/, '')) rescue nil
  end
end
