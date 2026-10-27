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

  Result = Struct.new(:created, :updated, :received, :skipped_exists, :skipped_no_vendor, :errors, keyword_init: true)

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
    load_existing(batches)

    batches.map do |po_key, rows|
      first = rows.first
      po_no = null_safe(first[COL_PO_NO])
      vendor_name = null_safe(first[COL_VENDOR_NAME])
      action = preview_action(first)

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

  # :create, :update or :skip_exists (in inventory, voided, history, or a PO number taken by another PDI PO).
  def preview_action(first)
    po = match(first)
    return history?(first) ? :skip_exists : :create if po.nil?

    refreshable?(po) ? :update : :skip_exists
  rescue ArgumentError
    :skip_exists
  end

  # Creates new PDI POs and keeps ones not yet in inventory in step with PDI (status, dates, warehouse,
  # lines). Received POs (Invoiced / Inventoried) go into inventory at their line costs when received on or
  # after the inventory start date at one of our warehouses; older or dropship POs are only marked posted
  # (PDI's inventory already has them). POs match on PDI's key, else the PO number.
  def run
    result = Result.new(created: 0, updated: 0, received: 0, skipped_exists: 0, skipped_no_vendor: 0, errors: [])
    batches = parse_batches
    load_existing(batches)
    @vendors_by_pdi_id = Vendor.all.index_by { |v| v.id.to_s }
    @locations_by_site = Location.all.index_by { |l| l.pdi_site_code.to_s }

    batches.each do |po_key, rows|
      import_po(rows, result)
    rescue StandardError => e
      result.errors << "PO #{po_key} (#{null_safe(rows.first[COL_PO_NO])}): #{e.message}"
    end

    result
  end

  def import_po(rows, result)
    first = rows.first
    po = match(first)
    return result.skipped_exists += 1 if po.nil? && history?(first)
    return skip_existing(po, first, result) if po && !refreshable?(po)

    action = po ? :updated : :created
    po ||= PurchaseOrder.new
    PurchaseOrder.transaction(requires_new: true) do
      save_po!(po, rows)
      result.received += 1 if receive!(po, null_safe(first[COL_STATUS]))
    end
    remember(po)
    result[action] += 1
  end

  def load_existing(batches)
    numbers = batches.values.filter_map { |rows| null_safe(rows.first[COL_PO_NO]) }
    found = PurchaseOrder.where(pdi_po_key: batches.keys).or(PurchaseOrder.where(pdi_reference: numbers)).to_a
    @by_key = found.select(&:pdi_po_key).index_by(&:pdi_po_key)
    @by_number = found.select(&:pdi_reference).index_by(&:pdi_reference)
  end

  # The app's PO for this PDI PO: by key, else by number. PO numbers are unique in the app, so a number
  # already taken by another PDI PO can't be imported.
  def match(first)
    key = first[COL_PO_KEY].to_s.strip
    return @by_key[key] if @by_key[key]

    po = @by_number[null_safe(first[COL_PO_NO])]
    raise ArgumentError, 'PO number is used by another PDI PO; skipped' if po&.pdi_po_key && po.pdi_po_key != key

    po
  end

  def remember(order)
    @by_key[order.pdi_po_key] = order
    @by_number[order.pdi_reference] ||= order if order.pdi_reference
  end

  # Numberless POs from before keys were stored can't be matched; once received before tracking began
  # there's nothing to bring in, so they aren't imported again.
  def history?(first)
    return false if null_safe(first[COL_PO_NO]) || STATUS_MAP[null_safe(first[COL_STATUS])] != 'received'

    start = InventoryRevaluation.start_date
    start.nil? || received_date(first).nil? || received_date(first).to_date < start
  end

  # Already in inventory (or voided): left as is, apart from recording PDI's key.
  def skip_existing(order, first, result)
    order.update_column(:pdi_po_key, first[COL_PO_KEY].to_s.strip) if order.pdi_po_key.nil?
    remember(order)
    result.skipped_exists += 1
  end

  # PDI POs the app hasn't put into inventory or voided.
  def refreshable?(order)
    order.from_pdi? && !order.posted? && !order.voided?
  end

  def save_po!(order, rows)
    first = rows.first
    order.assign_attributes(po_attributes(first))
    order.line_items.destroy_all if order.persisted?
    rows.uniq { |r| r[COL_LINE_KEY] }.each { |row| order.line_items.build(line_attributes(row)) }
    order.save!(validate: false) # Skip freight_terms validation for historical data
    business_date = parse_date(first[COL_BUSINESS_DATE])
    order.update_column(:created_at, business_date.to_time) if business_date
  end

  def po_attributes(first)
    pdi_status = null_safe(first[COL_STATUS]) || 'Entered'
    our_status = STATUS_MAP[pdi_status] || 'draft'
    { vendor: vendor_for(first), location: location_for(null_safe(first[COL_WH_SITE_ID])),
      pdi_reference: null_safe(first[COL_PO_NO]), pdi_po_key: first[COL_PO_KEY].to_s.strip, status: our_status,
      trigger_type: 'pdi_import',
      expected_delivery_date: parse_date(first[COL_DELIVERY_DATE]),
      submitted_at: parse_date(first[COL_ORDER_DATE])&.to_time,
      received_at: (received_date(first) if our_status == 'received'),
      freight_amount: null_safe_decimal(first[COL_FREIGHT_ON_INVC]) || 0,
      other_charges: null_safe_decimal(first[COL_OTHER_CHARGES]) || 0, notes: notes_for(first, pdi_status) }
  end

  # Invoice posting date, else inventory posting date, else the business date (Inventoried, not yet invoiced).
  def received_date(first)
    parse_datetime(first[COL_POSTED_INVC_DT]) || parse_datetime(first[COL_POSTED_INV_DT]) ||
      parse_date(first[COL_BUSINESS_DATE])&.to_time
  end

  def notes_for(first, pdi_status)
    comments = null_safe(first[COL_HEADER_COMMENTS])
    ["[PDI Import] #{null_safe(first[COL_PO_NO])}", pdi_status, comments].compact.join(' | ')
  end

  # PDI sends "110"; locations store "0110".
  def location_for(site)
    @locations_by_site[site.to_s] || @locations_by_site[site.to_s.rjust(4, '0')] if site
  end

  def vendor_for(first)
    pdi_vendor_id = null_safe(first[COL_VENDOR_ID])
    @vendors_by_pdi_id[pdi_vendor_id] ||= Vendor.create!(id: pdi_vendor_id, name: null_safe(first[COL_VENDOR_NAME]))
  end

  def line_attributes(row)
    { product_id: null_safe(row[COL_PROD_ID]), product_name: null_safe(row[COL_PROD_DESC]),
      quantity: null_safe_decimal(row[COL_INVENT_QTY]) || null_safe_decimal(row[COL_PURCH_QTY]) || 0,
      unit_cost: null_safe_decimal(row[COL_UNIT_COST]) || 0, package_code: null_safe(row[COL_PURCH_PKG]) }
  end

  # Received at one of our warehouses since costed tracking began.
  def received_into_tracking?(order)
    start = InventoryRevaluation.start_date
    start && order.location && order.received_at && order.received_at.to_date >= start
  end

  # True when the PO went into inventory at cost.
  def receive!(order, pdi_status)
    return false unless %w[Invoiced Inventoried].include?(pdi_status)

    return order.post_to_inventory!(nil) if received_into_tracking?(order)

    order.update_column(:posted_at, order.received_at || Time.current)
    false
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
