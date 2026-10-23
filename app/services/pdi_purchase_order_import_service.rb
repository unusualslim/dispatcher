require 'csv'

class PdiPurchaseOrderImportService
  # Header columns
  COL_PO_KEY           = 0
  COL_PO_NO            = 1
  COL_INVOICE_NO       = 2
  COL_VENDOR_ID        = 3
  COL_VENDOR_NAME      = 4
  COL_TERMS_ID         = 5
  COL_TERMS_DESC       = 6
  COL_INV_SITE_ID      = 7
  COL_INV_SITE_NAME    = 8
  COL_STATUS           = 9
  COL_DOC_TYPE         = 10
  COL_SOURCE_TYPE      = 11
  COL_ORDER_DATE       = 12
  COL_DELIVERY_DATE    = 13
  COL_SHIP_METHOD      = 14
  COL_BUSINESS_DATE    = 15
  COL_INVOICE_DATE     = 16
  COL_POSTED_INV_DT    = 17
  COL_POSTED_INVC_DT   = 18
  COL_INVOICE_TOTAL    = 19
  COL_OTHER_CHARGES    = 20
  COL_DISCOUNTS        = 21
  COL_FREIGHT_METHOD   = 22
  COL_FREIGHT_ON_INVC  = 23
  COL_FREIGHT_ACCRUAL  = 24
  COL_FREIGHT_VEND_ID  = 25
  COL_FREIGHT_VEND_NAME = 26
  COL_FREIGHT_INVC_NO = 27
  COL_FREIGHT_INVC_DATE = 28
  COL_FREIGHT_INVC_TOT = 29
  COL_FREIGHT_TERMS_ID = 30
  COL_FREIGHT_TERMS_DESC = 31
  COL_HEADER_COMMENTS = 32

  # Line columns
  COL_LINE_KEY = 33
  COL_WH_SITE_ID      = 34
  COL_WH_SITE_NAME    = 35
  COL_PROD_ID          = 36
  COL_PROD_DESC        = 37
  COL_PURCH_PKG        = 38
  COL_INVENT_PKG       = 39
  COL_ORDER_QTY        = 40
  COL_PURCH_QTY        = 41
  COL_INVOICE_QTY      = 42
  COL_INVENT_QTY       = 43
  COL_BACKORDER_QTY    = 44
  COL_INVOICE_VAR_QTY  = 45
  COL_UNIT_COST        = 46
  COL_EXT_COST         = 47
  COL_EXT_DISCOUNT     = 48
  COL_LINE_TOTAL_COST  = 49
  COL_LINE_FREIGHT     = 50
  COL_LINE_OTHER       = 51
  COL_LINE_DISCOUNTS   = 52
  COL_INVOICE_VAR_COST = 53
  COL_RECEIVING_STATUS = 54
  COL_LINE_COMMENTS    = 55

  # PDI status → our PO status
  STATUS_MAP = {
    'Entered' => 'draft',
    'Ordered' => 'submitted',
    'Invoiced' => 'received',
    'Inventoried' => 'received'
  }.freeze

  Result = Struct.new(:created, :skipped_exists, :skipped_no_vendor, :errors, keyword_init: true)

  PreviewRow = Struct.new(
    :po_key, :po_no, :vendor_name, :status, :order_date, :delivery_date,
    :business_date, :line_count, :total_cost, :action,
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
    po_nos = batches.values.map { |rows| null_safe(rows.first[COL_PO_NO]) }.compact
    existing_refs = PurchaseOrder.where(pdi_reference: po_nos).pluck(:pdi_reference).to_set

    batches.map do |po_key, rows|
      first = rows.first
      po_no = null_safe(first[COL_PO_NO])
      vendor_name = null_safe(first[COL_VENDOR_NAME])

      action = if po_no && existing_refs.include?(po_no)
                 :skip_exists
               else
                 :create
               end

      PreviewRow.new(
        po_key: po_key,
        po_no: po_no,
        vendor_name: vendor_name,
        status: null_safe(first[COL_STATUS]),
        order_date: parse_date(first[COL_ORDER_DATE]),
        delivery_date: parse_date(first[COL_DELIVERY_DATE]),
        business_date: parse_date(first[COL_BUSINESS_DATE]),
        line_count: rows.map { |r| r[COL_LINE_KEY] }.uniq.size,
        total_cost: null_safe_decimal(first[COL_INVOICE_TOTAL]),
        action: action
      )
    end
  end

  def run
    result = Result.new(created: 0, skipped_exists: 0, skipped_no_vendor: 0, errors: [])
    batches = parse_batches
    po_nos = batches.values.map { |rows| null_safe(rows.first[COL_PO_NO]) }.compact
    existing_refs = PurchaseOrder.where(pdi_reference: po_nos).pluck(:pdi_reference).to_set
    vendors_by_pdi_id = Vendor.all.index_by { |v| v.id.to_s }
    locations_by_site = Location.all.index_by { |l| l.pdi_site_code.to_s }

    batches.each do |po_key, rows|
      first = rows.first
      po_no = null_safe(first[COL_PO_NO])

      if po_no && existing_refs.include?(po_no)
        result.skipped_exists += 1
        next
      end

      pdi_vendor_id = null_safe(first[COL_VENDOR_ID])
      vendor_name   = null_safe(first[COL_VENDOR_NAME])

      # Find or create vendor
      vendor = vendors_by_pdi_id[pdi_vendor_id]
      unless vendor
        vendor = Vendor.create!(id: pdi_vendor_id, name: vendor_name)
        vendors_by_pdi_id[pdi_vendor_id] = vendor
      end

      pdi_status     = null_safe(first[COL_STATUS]) || 'Entered'
      our_status     = STATUS_MAP[pdi_status] || 'draft'
      order_date     = parse_date(first[COL_ORDER_DATE])
      delivery_date  = parse_date(first[COL_DELIVERY_DATE])
      business_date  = parse_date(first[COL_BUSINESS_DATE])
      posted_inv_dt  = parse_datetime(first[COL_POSTED_INV_DT])
      received_at    = parse_datetime(first[COL_POSTED_INVC_DT]) || posted_inv_dt
      freight_amount = null_safe_decimal(first[COL_FREIGHT_ON_INVC]) || 0
      other_charges  = null_safe_decimal(first[COL_OTHER_CHARGES]) || 0
      po_no          = null_safe(first[COL_PO_NO])
      comments       = null_safe(first[COL_HEADER_COMMENTS])
      wh_site_id     = null_safe(first[COL_WH_SITE_ID])
      location       = locations_by_site[wh_site_id] if wh_site_id

      notes = "[PDI Import] #{po_no}"
      notes += " | #{pdi_status}" if pdi_status
      notes += " | #{comments}" if comments

      po = PurchaseOrder.new(
        vendor: vendor,
        location: location,
        pdi_reference: po_no,
        status: our_status,
        trigger_type: 'pdi_import',
        expected_delivery_date: delivery_date,
        submitted_at: order_date ? order_date.to_time : nil,
        received_at: %w[received].include?(our_status) ? received_at : nil,
        posted_at: %w[Invoiced
                      Inventoried].include?(pdi_status) ? (posted_inv_dt || received_at || business_date&.to_time) : nil,
        freight_amount: freight_amount,
        other_charges: other_charges,
        notes: notes
      )

      # Build line items — deduplicate by line key
      line_rows = rows.uniq { |r| r[COL_LINE_KEY] }
      line_rows.each do |row|
        prod_id   = null_safe(row[COL_PROD_ID])
        prod_name = null_safe(row[COL_PROD_DESC])
        pkg_code  = null_safe(row[COL_PURCH_PKG])
        quantity  = null_safe_decimal(row[COL_INVENT_QTY]) || null_safe_decimal(row[COL_PURCH_QTY]) || 0
        unit_cost = null_safe_decimal(row[COL_UNIT_COST]) || 0

        po.line_items.build(
          product_id: prod_id,
          product_name: prod_name,
          quantity: quantity,
          unit_cost: unit_cost,
          package_code: pkg_code
        )
      end

      po.save!(validate: false) # Skip freight_terms validation for historical data
      # Override created_at to business date
      po.update_column(:created_at, business_date.to_time) if business_date
      result.created += 1
    rescue StandardError => e
      result.errors << "PO #{po_key} (#{null_safe(rows.first[COL_PO_NO])}): #{e.message}"
    end

    result
  end

  private

  def parse_batches
    rows = CSV.read(@file_path, headers: false, encoding: 'bom|utf-8')
    rows = rows[1..] if rows.first&.first.to_s.strip.downcase.include?('whprch_key')
    rows.group_by { |r| r[COL_PO_KEY].to_s.strip }
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
