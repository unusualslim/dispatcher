require 'roo'
require 'roo-xls'

class WarehouseTransactionImportService
  COL_BUSINESS_DATE = 0
  COL_TYPE          = 4
  COL_REFERENCE     = 7
  COL_PROD_DESC     = 9
  COL_QUANTITY      = 16
  COL_UNIT_COST     = 18

  TRANSACTION_TYPE_MAP = {
    'Purchases' => 'in',
  }.freeze

  Result     = Struct.new(:imported, :skipped_no_product, :skipped_unknown_type, :skipped_duplicate, :errors, keyword_init: true)
  PreviewRow = Struct.new(:product_id, :description, :product, :direction, :quantity, :unit_cost, :reference, :business_date, :action, keyword_init: true)

  def self.call(path)
    new(path).run
  end

  def initialize(path)
    @path = path
  end

  def preview
    rows = []
    wb = Roo::Excel.new(@path)

    (1..wb.last_row).each do |i|
      row = wb.row(i)
      next unless data_row?(row)

      type          = row[COL_TYPE].to_s.strip
      quantity      = row[COL_QUANTITY].to_f
      reference     = row[COL_REFERENCE].to_s.strip
      prod_desc     = row[COL_PROD_DESC].to_s.strip
      unit_cost     = row[COL_UNIT_COST]&.to_f
      business_date = row[COL_BUSINESS_DATE]

      next if quantity <= 0

      direction = TRANSACTION_TYPE_MAP[type]
      next unless direction

      product_id, description = prod_desc.split(' / ', 2)
      product_id = product_id.to_s.strip

      product = Product.find_by(id: product_id)
      unless product
        rows << PreviewRow.new(product_id: product_id, description: description.to_s, product: nil,
                               direction: direction, quantity: quantity, unit_cost: unit_cost,
                               reference: reference, business_date: business_date, action: :skip_no_product)
        next
      end

      if InventoryTransaction.exists?(product_id: product_id, reference_number: reference,
                                      notes: notes_for(description, unit_cost))
        rows << PreviewRow.new(product_id: product_id, description: description.to_s, product: product,
                               direction: direction, quantity: quantity, unit_cost: unit_cost,
                               reference: reference, business_date: business_date, action: :skip_duplicate)
        next
      end

      rows << PreviewRow.new(product_id: product_id, description: description.to_s, product: product,
                             direction: direction, quantity: quantity, unit_cost: unit_cost,
                             reference: reference, business_date: business_date, action: :import)
    end

    rows
  end

  def run
    result = Result.new(imported: 0, skipped_no_product: 0, skipped_unknown_type: 0, skipped_duplicate: 0, errors: [])

    wb = Roo::Excel.new(@path)
    (1..wb.last_row).each do |i|
      row = wb.row(i)
      next unless data_row?(row)

      business_date = row[COL_BUSINESS_DATE]
      type          = row[COL_TYPE].to_s.strip
      reference     = row[COL_REFERENCE].to_s.strip
      prod_desc     = row[COL_PROD_DESC].to_s.strip
      quantity      = row[COL_QUANTITY].to_f
      unit_cost     = row[COL_UNIT_COST]&.to_f

      next if quantity <= 0

      direction = TRANSACTION_TYPE_MAP[type]
      unless direction
        result.skipped_unknown_type += 1
        next
      end

      product_id, description = prod_desc.split(' / ', 2)
      product_id = product_id.to_s.strip

      product = Product.find_by(id: product_id)
      unless product
        result.skipped_no_product += 1
        next
      end

      # Duplicate guard: same reference + product + date
      if InventoryTransaction.exists?(
           product_id:       product_id,
           reference_number: reference,
           notes:            notes_for(description, unit_cost)
         )
        result.skipped_duplicate += 1
        next
      end

      InventoryTransaction.create!(
        product:          product,
        quantity:         quantity,
        direction:        direction,
        reference_number: reference,
        notes:            notes_for(description, unit_cost),
        created_at:       business_date.to_time
      )
      result.imported += 1
    rescue => e
      result.errors << "Row #{i} (#{product_id}): #{e.message}"
    end

    result
  end

  private

  def data_row?(row)
    row[COL_BUSINESS_DATE].is_a?(Date) &&
      row[COL_TYPE].present? &&
      row[COL_PROD_DESC].present? &&
      row[COL_PROD_DESC].to_s.include?(' / ')
  end

  def notes_for(description, unit_cost)
    note = "[PDI Historical Import] #{description}"
    note += " @ $#{'%.4f' % unit_cost}/unit" if unit_cost
    note
  end
end
