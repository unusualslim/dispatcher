require 'csv'

class VendorFreightTermImportsController < ApplicationController
  before_action :require_admin!

  def new
  end

  def create
    file = params[:file]
    return redirect_to new_vendor_freight_term_import_path, alert: "Please select a file." unless file

    begin
      csv = CSV.parse(file.read.encode('UTF-8', invalid: :replace, undef: :replace),
                      headers: true, header_converters: :symbol)
    rescue => e
      return redirect_to new_vendor_freight_term_import_path, alert: "Could not parse file: #{e.message}"
    end

    created  = 0
    skipped  = 0
    unknown  = Set.new

    csv.each do |row|
      vendor_id   = row[:vendor_id]&.to_s&.strip.presence || row[:vendorid]&.to_s&.strip.presence
      freight_term = row[:freight_term]&.to_s&.strip.presence ||
                     row[:freightterm]&.to_s&.strip.presence  ||
                     row[:freight_terms]&.to_s&.strip.presence

      next if vendor_id.blank? || freight_term.blank?

      vendor = Vendor.find_by(id: vendor_id)
      unless vendor
        unknown << vendor_id
        next
      end

      record = VendorFreightTerm.find_or_initialize_by(vendor_id: vendor_id, freight_term: freight_term)
      if record.new_record?
        record.save!
        created += 1
      else
        skipped += 1
      end
    end

    msg = "Import complete — #{created} term(s) added, #{skipped} already existed."
    msg += " Unknown vendor IDs (skipped): #{unknown.to_a.join(', ')}" if unknown.any?
    redirect_to vendors_path, notice: msg
  end
end
