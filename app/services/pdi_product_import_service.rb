require 'csv'

class PdiProductImportService
  # Column positions from PDI query:
  # select t1.prod_id, t1.prod_description, t2.ProdRptGrp_Description,
  #        t3.ProdPkg_Pkg_Code, t3.ProdPkg_Raw_Weight, t3.ProdPkg_Ship_Weight,
  #        t3.ProdPkg_UPC_Code, t3.ProdPkg_Mfg_Item_No, t3.ProdPkg_Mfg_Pack_Size
  COL_ID         = 0
  COL_NAME       = 1
  COL_CATEGORY   = 2
  COL_PKG_CODE   = 3
  COL_RAW_WEIGHT = 4
  COL_SHIP_WEIGHT = 5

  RAW_MATERIAL_CATEGORIES = %w[COMPONENTS COMPONENTS-LABELS COMPONENTS-BOXES COMPONENTS-BOTTLES COMPONENTS-BUCKETS].freeze

  Result = Struct.new(:created, :updated, :unchanged, :errors, keyword_init: true)

  PreviewRow = Struct.new(
    :product_id, :name, :category, :pkg_code, :weight,
    :existing_product, :action, :changes,
    keyword_init: true
  )

  def self.call(file_path)
    new(file_path).run
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def preview
    rows = parse_rows
    products_by_id = Product.where(id: rows.map { |r| r[COL_ID].to_s.strip }).index_by(&:id)

    rows.map do |row|
      product_id = row[COL_ID].to_s.strip
      next if product_id.blank?

      name      = row[COL_NAME].to_s.strip
      category  = null_safe(row[COL_CATEGORY])
      pkg_code  = null_safe(row[COL_PKG_CODE])
      weight    = null_safe_decimal(row[COL_RAW_WEIGHT])

      existing = products_by_id[product_id]

      if existing
        changes = compute_changes(existing, name, category, pkg_code, weight)
        action = changes.any? ? :update : :unchanged
      else
        changes = {}
        action = :create
      end

      PreviewRow.new(
        product_id: product_id, name: name, category: category,
        pkg_code: pkg_code, weight: weight,
        existing_product: existing, action: action, changes: changes
      )
    end.compact
  end

  def run
    result = Result.new(created: 0, updated: 0, unchanged: 0, errors: [])
    rows = parse_rows
    existing_ids = Product.where(id: rows.map { |r| r[COL_ID].to_s.strip }).pluck(:id).to_set

    rows.each do |row|
      product_id = row[COL_ID].to_s.strip
      next if product_id.blank?

      name      = row[COL_NAME].to_s.strip
      category  = null_safe(row[COL_CATEGORY])
      pkg_code  = null_safe(row[COL_PKG_CODE])
      weight    = null_safe_decimal(row[COL_RAW_WEIGHT])

      if existing_ids.include?(product_id)
        product = Product.find(product_id)
        changes = compute_changes(product, name, category, pkg_code, weight)
        if changes.any?
          product.update!(changes)
          result.updated += 1
        else
          result.unchanged += 1
        end
      else
        Product.create!(
          id:                  product_id,
          name:                name,
          category:            category,
          pdi_package_code:    pkg_code,
          unit_of_measurement: pkg_code,
          weight:              weight,
          is_raw_material:     raw_material?(category)
        )
        existing_ids.add(product_id)
        result.created += 1
      end
    rescue => e
      result.errors << "#{product_id}: #{e.message}"
    end

    result
  end

  private

  def parse_rows
    rows = CSV.read(@file_path, headers: false, encoding: 'bom|utf-8')
    # Skip header if present
    if rows.first&.first.to_s.strip.downcase.include?('prod_id')
      rows = rows[1..]
    end
    # Deduplicate by product ID (keep first occurrence)
    rows.uniq { |r| r[COL_ID].to_s.strip }
  end

  def compute_changes(product, name, category, pkg_code, weight)
    changes = {}
    changes[:name]                = name     if name.present? && product.name != name
    changes[:category]            = category if category.present? && product.category != category
    changes[:pdi_package_code]    = pkg_code if pkg_code.present? && product.pdi_package_code != pkg_code
    changes[:unit_of_measurement] = pkg_code if pkg_code.present? && product.unit_of_measurement != pkg_code
    changes[:weight]              = weight   if weight && product.weight.to_d != weight.to_d
    changes
  end

  def null_safe(value)
    v = value.to_s.strip
    v == 'NULL' || v.empty? ? nil : v
  end

  def null_safe_decimal(value)
    v = value.to_s.strip
    v == 'NULL' || v.empty? ? nil : v.to_d
  end

  def raw_material?(category)
    RAW_MATERIAL_CATEGORIES.any? { |c| category.to_s.start_with?(c) }
  end
end
