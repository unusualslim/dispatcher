require 'csv'

# Parses PDI's FI (fuel) Inventory Report — XLS, XLSX or CSV — and syncs fuel stock.
#
# The report lists tank readings grouped under "Site 0002 - FPS-Main" headers, one row per tank:
# col 0 tank, col 1 product ID, col 14 ending units, col 18 extended value. Ending units are
# summed per product and site into location_products (sites matched by Location#pdi_site_code),
# current_stock becomes the total across sites, and cost_per_unit PDI's weighted average.
class PdiInventoryImportService
  COL_TANK     = 0
  COL_PRODUCT  = 1
  COL_ENDING   = 14
  COL_EXTENDED = 18
  SITE_HEADER  = /\ASite\s+(\d+)\s*-\s*(.+)\z/

  Row = Struct.new(:site_code, :site_name, :tank, :product_id, :ending, :extended, keyword_init: true)

  def initialize(file, user = nil)
    @file = file
    @user = user
  end

  # Returns { updated:, skipped:, unmatched_products: [...], unmatched_sites: [...], errors: [...] }
  def import
    result = { updated: 0, skipped: 0, unmatched_products: [], unmatched_sites: [], errors: [] }
    rows = parse_rows
    products = Product.where(id: rows.map(&:product_id).uniq).index_by(&:id)
    rows.group_by(&:product_id).each do |product_id, product_rows|
      import_product(products[product_id], product_id, product_rows, result)
    end
    result[:unmatched_sites].uniq!
    result
  end

  private

  def import_product(product, product_id, product_rows, result)
    return skip_product(product_id, result) unless product

    ActiveRecord::Base.transaction do
      matched = sync_sites!(product, product_rows, result)
      update_totals!(product, product_rows, matched)
    end
    result[:updated] += 1
  rescue StandardError => e
    result[:errors] << "#{product_id}: #{e.message}"
  end

  def skip_product(product_id, result)
    result[:skipped] += 1
    result[:unmatched_products] << product_id
  end

  # Returns true when at least one of the product's sites maps to a location.
  def sync_sites!(product, product_rows, result)
    product_rows.group_by(&:site_code).map do |site_code, site_rows|
      location = locations_by_site[site_code]
      result[:unmatched_sites] << "#{site_code} #{site_rows.first.site_name}" unless location
      location && set_location_stock!(product, location, site_rows.sum(&:ending))
    end.any?
  end

  # current_stock is the total across mapped sites (the report total when none map).
  def update_totals!(product, product_rows, matched)
    ending = product_rows.sum(&:ending)
    stock = matched ? LocationProduct.where(product_id: product.id).sum(:quantity) : ending
    attrs = { current_stock: stock }
    attrs[:cost_per_unit] = (product_rows.sum(&:extended) / ending).round(4) if ending.positive?
    product.update!(attrs)
  end

  # Brings the site to PDI's quantity; the difference posts as a "PDI sync" movement at the app's cost.
  def set_location_stock!(product, location, ending)
    current = LocationProduct.find_by(location_id: location.id, product_id: product.id)&.quantity.to_d
    InventoryPosting.post!(product: product, location: location, quantity: ending - current, movement_type: 'pdi_sync',
                           reference: "PDI-FI-#{Time.zone.today.strftime('%Y%m%d')}", user: @user,
                           notes: "PDI FI Inventory Report sync — ending #{ending}")
    true
  end

  def locations_by_site
    @locations_by_site ||= Location.where.not(pdi_site_code: [nil, '']).index_by(&:pdi_site_code)
  end

  def parse_rows
    site = nil
    raw_rows.filter_map do |raw|
      if (m = raw[COL_TANK].to_s.strip.match(SITE_HEADER))
        site = m.captures
        next
      end
      tank_row(raw, *site) if site
    end
  end

  # A tank line: numeric tank, a product ID and an ending quantity (skips totals and headings).
  def tank_row(raw, site_code, site_name)
    tank = tank_number(raw[COL_TANK])
    product_id = raw[COL_PRODUCT].to_s.strip
    ending = number(raw[COL_ENDING])
    return if tank.nil? || product_id.blank? || ending.nil?

    Row.new(site_code: site_code, site_name: site_name.strip, tank: tank, product_id: product_id,
            ending: ending, extended: number(raw[COL_EXTENDED]) || 0.to_d)
  end

  # Tank numbers arrive as "1.0" from XLS; anything non-numeric is a heading or total.
  def tank_number(value)
    tank = value.to_s.strip
    tank.sub(/\.0+\z/, '') if tank.match?(/\A\d+(\.0+)?\z/)
  end

  def raw_rows
    path = @file.respond_to?(:path) ? @file.path : @file.to_s
    name = @file.respond_to?(:original_filename) ? @file.original_filename : path
    ext = File.extname(name).downcase
    return CSV.read(path, encoding: 'bom|utf-8') if ext == '.csv'

    sheet = Roo::Spreadsheet.open(path, extension: ext == '.xlsx' ? :xlsx : :xls).sheet(0)
    (1..sheet.last_row).map { |i| sheet.row(i) }
  end

  def number(value)
    BigDecimal(value.to_s.delete(',')) if value.present?
  rescue ArgumentError
    nil
  end
end
