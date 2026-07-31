require 'csv'

class VendorFreightTermImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'Vendor Freight Term Import'.freeze

  def new
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    file = params[:file]
    return redirect_to new_vendor_freight_term_import_path, alert: "Please select a file." unless file

    begin
      csv = CSV.parse(file.read.encode('UTF-8', invalid: :replace, undef: :replace),
                      headers: true, header_converters: :symbol)
    rescue => e
      return redirect_to new_vendor_freight_term_import_path, alert: "Could not parse file: #{e.message}"
    end

    @rows = []
    csv.each do |row|
      vendor_id    = row[:vendor_id]&.to_s&.strip.presence || row[:vendorid]&.to_s&.strip.presence
      freight_term = row[:freight_term]&.to_s&.strip.presence ||
                     row[:freightterm]&.to_s&.strip.presence  ||
                     row[:freight_terms]&.to_s&.strip.presence
      next if vendor_id.blank? || freight_term.blank?

      vendor = Vendor.find_by(id: vendor_id)
      already_exists = vendor && VendorFreightTerm.exists?(vendor_id: vendor_id, freight_term: freight_term)

      @rows << {
        vendor_id:      vendor_id,
        freight_term:   freight_term,
        vendor:         vendor,
        already_exists: already_exists
      }
    end

    @file_name = file.original_filename
  end

  def create
    rows = params[:rows] || []
    created  = 0
    skipped  = 0
    warnings = []

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      file_name:    params[:file_name].presence || 'unknown',
      started_at:   Time.current
    )

    begin
      rows.each do |_, r|
        vendor_id    = r[:vendor_id].to_s.strip
        freight_term = r[:freight_term].to_s.strip
        next if vendor_id.blank? || freight_term.blank?

        record = VendorFreightTerm.find_or_initialize_by(vendor_id: vendor_id, freight_term: freight_term)
        if record.new_record?
          record.save!
          created += 1
        else
          skipped += 1
        end
      end

      log.update!(
        status:          'success',
        completed_at:    Time.current,
        records_created: created,
        records_skipped: skipped,
        warnings:        warnings.any? ? warnings.join("\n") : nil
      )
    rescue => e
      log.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
      return redirect_to new_vendor_freight_term_import_path, alert: "Import failed: #{e.message}"
    end

    redirect_to new_vendor_freight_term_import_path,
                notice: "Import complete — #{created} term(s) added, #{skipped} already existed."
  end
end
