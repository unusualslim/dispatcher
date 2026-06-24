require 'csv'
require 'net/ftp'

class PdiVendorImportService
  # PDI AP Vendor List CSV column positions (0-indexed, skipping blank col 0)
  # Group1textbox6, Vend_ID, Vend_Description, Vend_Address_1, Vend_Address_2,
  # Vend_City, State_Code, Vend_City_1 (zip), APTerms_ID, PaymentMethod, Vend_Masked_Phone
  COL_VEND_ID      = 1
  COL_NAME         = 2
  COL_ADDRESS_1    = 3
  COL_ADDRESS_2    = 4
  COL_CITY         = 5
  COL_STATE        = 6
  COL_ZIP          = 7
  COL_TERMS        = 8
  COL_PAY_METHOD   = 9
  COL_PHONE        = 10

  Result = Struct.new(:created, :updated, :skipped, :errors, keyword_init: true)

  def self.call(csv_content)
    new(csv_content).run
  end

  def initialize(csv_content)
    @csv_content = csv_content
  end

  def run
    result = Result.new(created: 0, updated: 0, skipped: 0, errors: [])

    rows = CSV.parse(@csv_content, headers: true)
    rows.each do |row|
      pdi_id = row[COL_VEND_ID].to_s.strip
      name   = row[COL_NAME].to_s.strip
      next if pdi_id.blank? || name.blank?

      attrs = {
        name:           name,
        address_1:      row[COL_ADDRESS_1].to_s.strip.presence,
        address_2:      row[COL_ADDRESS_2].to_s.strip.presence,
        city:           row[COL_CITY].to_s.strip.presence,
        state:          row[COL_STATE].to_s.strip.presence,
        zip:            row[COL_ZIP].to_s.strip.presence,
        payment_terms:  row[COL_TERMS].to_s.strip.presence,
        payment_method: row[COL_PAY_METHOD].to_s.strip.presence,
        phone:          row[COL_PHONE].to_s.strip.presence,
      }.compact

      vendor = Vendor.find_by(id: pdi_id)

      if vendor
        vendor.update!(attrs)
        result.updated += 1
      else
        Vendor.create!(attrs.merge(id: pdi_id))
        result.created += 1
      end
    rescue => e
      result.errors << "Vend_ID #{pdi_id}: #{e.message}"
      result.skipped += 1
    end

    result
  end
end
