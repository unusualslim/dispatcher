require 'csv'

# Parses a PDI FI Inventory Report CSV and updates current_stock on matching products.
# Matches rows by Product.pdi_tank_id == Tank column (col 0).
# Sets current_stock to the Ending inventory value (col 14) and logs an InventoryTransaction.
class PdiInventoryImportService
  ENDING_COL = 14

  def initialize(file, user)
    @file = file
    @user = user
  end

  def import
    updated = 0
    skipped = 0
    errors  = []

    parse_data_rows.each do |row|
      tank_id = row[0].to_s.strip
      ending  = parse_number(row[ENDING_COL])

      product = Product.find_by(pdi_tank_id: tank_id)
      unless product
        skipped += 1
        next
      end

      begin
        set_stock!(product, ending)
        updated += 1
      rescue => e
        errors << "#{product.name}: #{e.message}"
      end
    end

    { updated: updated, skipped: skipped, errors: errors }
  end

  private

  def parse_data_rows
    content = @file.respond_to?(:read) ? @file.read : File.read(@file)
    content = content.force_encoding('UTF-8').scrub

    CSV.parse(content).select do |row|
      row[0].to_s.strip =~ /^\d+$/ && row[ENDING_COL].to_s.strip.present?
    end
  end

  def parse_number(val)
    val.to_s.gsub(/,/, '').to_d
  end

  def set_stock!(product, ending)
    old_stock = product.current_stock || 0
    delta     = ending - old_stock
    return if delta == 0

    direction = delta > 0 ? 'in' : 'out'
    quantity  = delta.abs

    ActiveRecord::Base.transaction do
      InventoryTransaction.create!(
        product:          product,
        quantity:         quantity,
        direction:        direction,
        reference_number: "PDI-#{Date.today.strftime('%Y%m%d')}",
        notes:            "PDI FI Inventory Report sync — ending #{ending}",
        created_by_id:    @user.id
      )

      product.update!(current_stock: ending)
    end
  end
end
