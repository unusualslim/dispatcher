class PdiWarehouseTransactionImportService
  # Warehouse Transaction Report (XLS) — filtered to Purchases only
  # Column indices (0-based):
  COL_BUSINESS_DATE = 0   # Excel serial float, or site header string
  COL_TYPE          = 4   # 'Purchases'
  COL_REFERENCE     = 7   # PDI PO reference e.g. 'FPS1102'
  COL_PRODUCT       = 9   # 'PROD_ID / Description'
  COL_PACKAGE       = 15  # Package/unit code e.g. 'EA', 'GA'
  COL_QUANTITY      = 16
  COL_UNIT_COST     = 18

  EXCEL_EPOCH = Date.new(1899, 12, 30)

  ParsedRow = Struct.new(:vendor_id, :vendor_name, :pdi_reference, :product_id,
                         :product_name, :quantity, :unit_cost, :package_code,
                         :business_date, keyword_init: true)

  PoPreview = Struct.new(:pdi_reference, :line_count, :total_cost, :business_date,
                         :already_imported, :lines, keyword_init: true)

  VendorGroup = Struct.new(:vendor_id, :vendor_name, :vendor, :pos, keyword_init: true)

  def initialize(file)
    @file = file
  end

  def preview
    rows = parse_rows
    existing_refs = PurchaseOrder.where(pdi_reference: rows.map(&:pdi_reference).uniq).pluck(:pdi_reference).to_set

    rows.group_by(&:vendor_id).map do |vendor_id, lines|
      pos = lines.group_by(&:pdi_reference).map do |reference, po_lines|
        PoPreview.new(
          pdi_reference:    reference,
          line_count:       po_lines.size,
          total_cost:       po_lines.sum { |l| (l.quantity || 0) * (l.unit_cost || 0) },
          business_date:    po_lines.first.business_date,
          already_imported: existing_refs.include?(reference),
          lines:            po_lines
        )
      end

      VendorGroup.new(
        vendor_id:   vendor_id,
        vendor_name: lines.first.vendor_name,
        vendor:      Vendor.find_by(id: vendor_id),
        pos:         pos
      )
    end
  end

  def import(selected_references: nil, vendor_actions: {}, import_status: 'received')
    rows   = parse_rows
    counts = { created: 0, skipped: 0, errors: 0 }
    warnings = []

    # Resolve vendor actions: create new ones, build override map for matched ones
    # vendor_actions: { pdi_id => "create" | "skip" | existing_vendor_id }
    vendor_overrides = {}  # pdi_id => Vendor record
    vendor_actions.each do |pdi_id, action|
      next if action.blank? || action == 'skip'
      if action == 'create'
        next if Vendor.exists?(id: pdi_id)
        vendor_name = rows.find { |r| r.vendor_id == pdi_id }&.vendor_name.to_s
        unique_name = Vendor.exists?(name: vendor_name) ? "#{vendor_name} (#{pdi_id})" : vendor_name
        vendor_overrides[pdi_id] = Vendor.create!(id: pdi_id, name: unique_name)
      else
        # action is an existing vendor id
        v = Vendor.find_by(id: action)
        vendor_overrides[pdi_id] = v if v
      end
    rescue => e
      warnings << "Could not resolve vendor #{pdi_id}: #{e.message}"
    end

    rows.group_by(&:pdi_reference).each do |reference, lines|
      next if selected_references && !selected_references.include?(reference)

      if PurchaseOrder.exists?(pdi_reference: reference)
        counts[:skipped] += 1
        next
      end

      first  = lines.first
      vendor = vendor_overrides[first.vendor_id] || Vendor.find_by(id: first.vendor_id)

      unless vendor
        warnings << "Vendor '#{first.vendor_id} / #{first.vendor_name}' not found — skipping PO #{reference}"
        counts[:errors] += 1
        next
      end

      begin
        ActiveRecord::Base.transaction do
          po = PurchaseOrder.create!(
            vendor:        vendor,
            status:        import_status,
            trigger_type:  'pdi_import',
            pdi_reference: reference,
            received_at:   (import_status == 'received' ? first.business_date&.to_time : nil),
            notes:         'Imported from PDI warehouse transaction report'
          )
          lines.each do |line|
            product = Product.find_by(id: line.product_id)
            po.line_items.create!(
              product:      product,
              product_id:   line.product_id,
              product_name: line.product_name,
              quantity:     line.quantity,
              unit_cost:    line.unit_cost,
              package_code: line.package_code
            )
          end
        end
        counts[:created] += 1
      rescue => e
        warnings << "Error creating PO #{reference}: #{e.message}"
        counts[:errors] += 1
      end
    end

    counts.merge(warnings: warnings)
  end

  private

  def parse_rows
    rows = []
    current_vendor_id   = nil
    current_vendor_name = nil

    each_sheet_row do |raw|
      col0 = raw[COL_BUSINESS_DATE]

      # Site header rows: string with " / " but not a summary line
      if col0.is_a?(String) && col0.include?(' / ') && !col0.start_with?('Calculated')
        parts               = col0.split(' / ', 2)
        current_vendor_id   = parts[0].strip
        current_vendor_name = parts[1].strip
        next
      end

      # Data rows: col0 is a Date (roo parses it), type must be 'Purchases'
      next unless col0.is_a?(Date)
      next unless raw[COL_TYPE].to_s.strip == 'Purchases'

      reference = raw[COL_REFERENCE].to_s.strip
      next if reference.blank?

      product_id, product_name = raw[COL_PRODUCT].to_s.strip.split(' / ', 2)

      rows << ParsedRow.new(
        vendor_id:     current_vendor_id,
        vendor_name:   current_vendor_name,
        pdi_reference: reference,
        product_id:    product_id.to_s.strip,
        product_name:  product_name.to_s.strip,
        quantity:      raw[COL_QUANTITY].to_f,
        unit_cost:     raw[COL_UNIT_COST].to_f,
        package_code:  raw[COL_PACKAGE].to_s.strip,
        business_date: col0
      )
    end

    rows
  end

  def each_sheet_row
    path = @file.respond_to?(:path) ? @file.path : @file.to_s
    ext  = File.extname(path).downcase

    spreadsheet = if ext == '.xls'
      Roo::Spreadsheet.open(path, extension: :xls)
    else
      Roo::Spreadsheet.open(path, extension: :xlsx)
    end

    sheet = spreadsheet.sheet(0)
    (1..sheet.last_row).each { |i| yield sheet.row(i) }
  end

  def excel_date(serial)
    return nil unless serial.is_a?(Numeric)
    EXCEL_EPOCH + serial.to_i
  rescue
    nil
  end
end
