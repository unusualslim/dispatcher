class InventoryImportService
  # PDI "by site by reporting group" inventory export format
  # Col 0:  site header ("110 / FPS-South"), category header ("COMPONENTS"), or product ("PART / DESC")
  # Col 17: on-hand quantity (nil/blank for site/category headers, numeric for products)
  # Col 19: total extended cost — divided by quantity to get cost_per_unit
  COL_COMBINED   = 0
  COL_QUANTITY   = 17
  COL_TOTAL_COST = 19

  # site_code: PDI site code string (e.g. "110"), site_name: PDI site name (e.g. "FPS-South")
  ImportRow = Struct.new(:part_number, :description, :category, :quantity,
                         :cost_per_unit, :product, :action,
                         :site_code, :site_name, keyword_init: true)

  def initialize(file)
    @file = file
  end

  # Returns an array of ImportRow structs — does NOT write to DB.
  def preview
    rows             = []
    current_category = nil
    current_site_code = nil
    current_site_name = nil

    parse_spreadsheet.each do |raw|
      combined = raw[COL_COMBINED].to_s.strip
      next if combined.blank?

      if combined.include?(' / ')
        left, right = combined.split(' / ', 2)
        left  = left.to_s.strip
        right = right.to_s.strip

        # Site header: short pure-numeric code + blank quantity
        if left.match?(/\A\d{1,4}\z/) && raw[COL_QUANTITY].nil?
          current_site_code = left
          current_site_name = right
          next
        end

        # Product row — must have a parseable quantity
        qty = parse_quantity(raw[COL_QUANTITY])
        next if qty.nil?
        next if left.blank? || right.blank?

        total_cost    = parse_quantity(raw[COL_TOTAL_COST])
        cost_per_unit = (total_cost && qty > 0) ? (total_cost / qty).round(4) : nil
        product       = Product.find_by(id: left)

        rows << ImportRow.new(
          part_number:   left,
          description:   right,
          category:      current_category.to_s,
          quantity:      qty,
          cost_per_unit: cost_per_unit,
          product:       product,
          action:        product ? :update : :create,
          site_code:     current_site_code,
          site_name:     current_site_name
        )
      else
        # Category/group header (no ' / ')
        current_category = combined unless combined.start_with?('Total for')
      end
    end

    rows
  end

  # Returns unique sites found in the file: [{code:, name:}, ...]
  def sites
    preview.map { |r| { code: r.site_code, name: r.site_name } }
           .uniq
           .reject { |s| s[:code].nil? }
  end

  # Applies the import.
  # site_location_map: hash of { "site_code" => Location } for warehouse-aware import.
  #   Products belonging to a mapped site are upserted into location_products.
  #   Products with no site mapping only update product attrs (category, cost).
  # selected_part_numbers: optional allowlist of part numbers to import.
  # Returns { updated: N, created: N, skipped: N }
  def import(selected_part_numbers: nil, site_location_map: {})
    rows   = preview
    counts = { updated: 0, created: 0, skipped: 0 }

    # A product can appear multiple times within the same site (across reporting groups).
    # Aggregate quantities by part_number+site_code before upserting so we sum, not overwrite.
    site_qty_totals = Hash.new(0)  # [part_number, site_code] => total_qty

    # First pass: update/create product records and accumulate site quantities
    seen_parts = Set.new

    rows.each do |row|
      if selected_part_numbers && !selected_part_numbers.include?(row.part_number)
        counts[:skipped] += 1 unless seen_parts.include?(row.part_number)
        seen_parts << row.part_number
        next
      end

      site_qty_totals[[row.part_number, row.site_code]] += row.quantity

      # Only update product attrs once per part number
      unless seen_parts.include?(row.part_number)
        seen_parts << row.part_number

        attrs = { category: row.category, cost_per_unit: row.cost_per_unit }.compact

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
    end

    # Second pass: upsert location_products using summed quantities, then sync current_stock
    products_to_sync = Set.new
    site_qty_totals.each do |(part_number, site_code), total_qty|
      location = site_location_map[site_code]
      next unless location

      product = Product.find_by(id: part_number)
      next unless product

      lp = LocationProduct.find_or_initialize_by(location_id: location.id, product_id: product.id)
      lp.quantity = total_qty
      lp.save!
      products_to_sync << product.id
    end

    products_to_sync.each do |product_id|
      product = Product.find(product_id)
      product.update_column(:current_stock, LocationProduct.where(product_id: product_id).sum(:quantity))
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
