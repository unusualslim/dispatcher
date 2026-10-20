require 'csv'

class RepackBatchImportService
  # Batch-level columns
  COL_BATCH_KEY        = 0
  COL_BATCH_DESC       = 1
  COL_BUSINESS_DATE    = 2
  COL_BATCH_STATUS     = 3
  COL_POSTED_DATETIME  = 4
  COL_ENTRY_DATETIME   = 5
  COL_BATCH_SOURCE     = 6
  COL_CREDIT_BATCH     = 7
  COL_WAREHOUSE_ID     = 8
  COL_WAREHOUSE_NAME   = 9

  # Repack (finished product) columns
  COL_REPACK_PROD_KEY  = 12
  COL_REPACK_PROD_ID   = 13
  COL_REPACK_DESC      = 14
  COL_REPACK_PKG_CODE  = 15
  COL_REPACK_QTY       = 16
  COL_FORMULA_OVERRIDE = 17

  # Cost/fee columns
  COL_COMP_TOTAL_COST  = 18
  COL_TOTAL_FEES       = 19
  COL_EST_TOTAL_COST   = 20
  COL_FEE_METHOD       = 21
  COL_FEE_AMOUNT       = 22

  # Byproduct columns
  COL_BYPROD_ID        = 23
  COL_BYPROD_DESC      = 24
  COL_BYPROD_PKG       = 25
  COL_BYPROD_QTY       = 26
  COL_BYPROD_COST      = 27

  # Component columns
  COL_COMP_KEY         = 28
  COL_COMP_PROD_ID     = 29
  COL_COMP_DESC        = 30
  COL_COMP_TYPE        = 31
  COL_COMP_PKG_CODE    = 32
  COL_COMP_TANK_NO     = 33
  COL_COMP_DEFAULT_QTY = 34
  COL_COMP_ACTUAL_QTY  = 35
  COL_COMP_TOTAL_QTY   = 36
  COL_COMP_EST_COST    = 37
  COL_COMP_EXT_COST    = 38
  COL_COMP_SOURCE      = 39

  Result = Struct.new(:created, :skipped_exists, :skipped_reversed, :skipped_no_product, :errors, keyword_init: true)

  PreviewRow = Struct.new(
    :batch_key, :description, :business_date, :status, :source,
    :product_id, :product_name, :product, :qty,
    :warehouse_name, :component_count, :action,
    keyword_init: true
  )

  def self.call(file_path)
    new(file_path).run
  end

  def initialize(file_path)
    @file_path = file_path
  end

  def preview
    batches = parse_batches
    existing_numbers = ProductionOrder.where(number: batches.keys.map { |k| "PDI-#{k}" }).pluck(:number).to_set

    batches.map do |batch_key, rows|
      first = rows.first
      status = null_safe(first[COL_BATCH_STATUS])
      product_id = null_safe(first[COL_REPACK_PROD_ID])
      product = Product.find_by(id: product_id) if product_id

      action = if status == 'Reversed'
                 :skip_reversed
               elsif existing_numbers.include?("PDI-#{batch_key}")
                 :skip_exists
               elsif product_id && product.nil?
                 :skip_no_product
               else
                 :create
               end

      comp_count = rows.map { |r| null_safe(r[COL_COMP_KEY]) }.compact.uniq.size

      PreviewRow.new(
        batch_key:       batch_key,
        description:     null_safe(first[COL_BATCH_DESC]),
        business_date:   parse_date(first[COL_BUSINESS_DATE]),
        status:          status,
        source:          null_safe(first[COL_BATCH_SOURCE]),
        product_id:      product_id,
        product_name:    null_safe(first[COL_REPACK_DESC]) || product&.name,
        product:         product,
        qty:             null_safe_decimal(first[COL_REPACK_QTY]),
        warehouse_name:  null_safe(first[COL_WAREHOUSE_NAME]),
        component_count: comp_count,
        action:          action
      )
    end
  end

  def run
    result = Result.new(created: 0, skipped_exists: 0, skipped_reversed: 0, skipped_no_product: 0, errors: [])
    batches = parse_batches
    existing_numbers = ProductionOrder.where(number: batches.keys.map { |k| "PDI-#{k}" }).pluck(:number).to_set
    locations_by_name = Location.all.index_by { |l| l.company_name.to_s.strip.downcase }

    batches.each do |batch_key, rows|
      first = rows.first
      status = null_safe(first[COL_BATCH_STATUS])

      if status == 'Reversed'
        result.skipped_reversed += 1
        next
      end

      number = "PDI-#{batch_key}"
      if existing_numbers.include?(number)
        result.skipped_exists += 1
        next
      end

      product_id = null_safe(first[COL_REPACK_PROD_ID])
      product = Product.find_by(id: product_id) if product_id
      unless product
        result.skipped_no_product += 1
        result.errors << "Batch #{batch_key}: product #{product_id} (#{null_safe(first[COL_REPACK_DESC])}) not found"
        next
      end

      business_date = parse_date(first[COL_BUSINESS_DATE])
      posted_at     = parse_datetime(first[COL_POSTED_DATETIME])
      entry_at      = parse_datetime(first[COL_ENTRY_DATETIME])
      qty           = null_safe_decimal(first[COL_REPACK_QTY]) || 0
      batch_source  = null_safe(first[COL_BATCH_SOURCE])
      credit        = null_safe(first[COL_CREDIT_BATCH])
      wh_name       = null_safe(first[COL_WAREHOUSE_NAME])
      location      = locations_by_name[wh_name.to_s.strip.downcase] if wh_name

      po_status = status == 'Posted' ? 'completed' : 'pending'

      notes = "[PDI Historical Import] #{null_safe(first[COL_BATCH_DESC])}"
      notes += " | Source: #{batch_source}" if batch_source
      notes += " | Credit batch" if credit == 'Yes'

      po = ProductionOrder.new(
        number:           number,
        product:          product,
        item:             product.name,
        status:           po_status,
        qty_to_make:      qty,
        total_qty_produced: po_status == 'completed' ? qty : nil,
        due_date:         business_date,
        production_date:  business_date,
        date_started:     business_date,
        date_completed:   po_status == 'completed' ? (posted_at&.to_date || business_date) : nil,
        location:         location,
        location_name:    wh_name,
        notes:            notes
      )

      # Build components from component rows
      comp_rows = rows
        .select { |r| null_safe(r[COL_COMP_KEY]).present? }
        .uniq { |r| r[COL_COMP_KEY] }

      comp_rows.each_with_index do |row, idx|
        comp_prod_id = null_safe(row[COL_COMP_PROD_ID])
        comp_product = Product.find_by(id: comp_prod_id) if comp_prod_id
        total_qty    = null_safe_decimal(row[COL_COMP_TOTAL_QTY]) || 0

        po.production_order_components.build(
          position:        idx + 1,
          product_id:      comp_product&.id,
          part_number:     comp_prod_id,
          description:     null_safe(row[COL_COMP_DESC]),
          uom:             null_safe(row[COL_COMP_PKG_CODE]) || 'EA',
          quantity:         total_qty,
          quantity_actual:  total_qty
        )
      end

      po.save!
      # Override created_at to entry datetime if available
      po.update_column(:created_at, entry_at) if entry_at
      result.created += 1
    rescue => e
      result.errors << "Batch #{batch_key}: #{e.message}"
    end

    result
  end

  private

  def parse_batches
    rows = CSV.read(@file_path, headers: false, encoding: 'bom|utf-8')
    # Skip header row if present
    if rows.first&.first.to_s.strip.downcase.include?('batch_key')
      rows = rows[1..]
    end
    rows.group_by { |r| r[COL_BATCH_KEY].to_s.strip }
  end

  def null_safe(value)
    v = value.to_s.strip
    v == 'NULL' || v.empty? ? nil : v
  end

  def null_safe_decimal(value)
    v = value.to_s.strip
    v == 'NULL' || v.empty? ? nil : v.to_d
  end

  def parse_date(value)
    v = null_safe(value)
    return nil unless v
    Date.parse(v) rescue nil
  end

  def parse_datetime(value)
    v = null_safe(value)
    return nil unless v
    Time.parse(v) rescue nil
  end
end
