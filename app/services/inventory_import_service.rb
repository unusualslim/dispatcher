class InventoryImportService
  # PDI warehouse inventory export format (WIWI / Fishbowl)
  # Col 0:  "PART_NUMBER / DESCRIPTION" for product rows, or category name for section headers
  # Col 17: on-hand quantity
  # Col 19: total extended cost (col T) — divided by quantity to get cost_per_unit
  COL_COMBINED    = 0
  COL_QUANTITY    = 17
  COL_TOTAL_COST  = 19

  ImportRow = Struct.new(:part_number, :description, :category, :quantity,
                         :cost_per_unit, :product, :action, keyword_init: true)

  def initialize(file)
    @file = file
  end

  # Returns an array of ImportRow structs — does NOT write to DB.
  # action: :update (matched product), :create (no match)
  def preview
    rows = []
    current_category = nil

    parse_spreadsheet.each do |raw|
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

total_cost    = parse_quantity(raw[COL_TOTAL_COST])
      cost_per_unit = (total_cost && qty > 0) ? (total_cost / qty).round(4) : nil

      product = Product.find_by(id: part_number)

      rows << ImportRow.new(
        part_number:   part_number,
        description:   description,
        category:      current_category.to_s,
        quantity:      qty,
        cost_per_unit: cost_per_unit,
        product:       product,
        action:        product ? :update : :create
      )
    end
    rows
  end

  # Applies the import. Returns { updated: N, created: N, skipped: N }
  def import(selected_part_numbers: nil)
    rows   = preview
    counts = { updated: 0, created: 0, skipped: 0 }

    rows.each do |row|
      if selected_part_numbers && !selected_part_numbers.include?(row.part_number)
        counts[:skipped] += 1
        next
      end

      attrs = {
        current_stock:  row.quantity,
        category:       row.category,
        cost_per_unit:  row.cost_per_unit
      }.compact

      case row.action
      when :update
        row.product.update!(attrs)
        counts[:updated] += 1
      when :create
        existing = Product.find_by(id: row.part_number)
        if existing
          existing.update!(attrs)
          counts[:updated] += 1
        else
          Product.create!(attrs.merge(
            id:              row.part_number,
            name:            row.description,
            is_raw_material: raw_material_category?(row.category)
          ))
          counts[:created] += 1
        end
      end
    end

    counts
  end

  private

  def parse_spreadsheet
    path = @file.respond_to?(:path) ? @file.path : @file.to_s
    ext  = File.extname(path).downcase

    spreadsheet = if ext == '.xls'
      Roo::Spreadsheet.open(path, extension: :xls)
    else
      Roo::Spreadsheet.open(path, extension: :xlsx)
    end

    sheet = spreadsheet.sheet(0)
    rows  = []
    (2..sheet.last_row).each { |i| rows << sheet.row(i) }
    rows
  end

  def raw_material_category?(category)
    category.to_s.upcase.include?('COMPONENT')
  end

  def parse_quantity(val)
    return nil if val.blank?
    Float(val.to_s.gsub(/,/, '')) rescue nil
  end
end
