class CustomerOrderImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'Customer Order Import'.freeze

  def new
    @order_count = CustomerOrder.count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def create
    file = params[:file]
    return redirect_to new_customer_order_import_path, alert: "Please select a file." unless file

    unless file.original_filename.downcase.end_with?('.pdf')
      return redirect_to new_customer_order_import_path, alert: "File must be a PDF file."
    end

    file_content = file.read

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      file_name:    file.original_filename,
      file_content: Base64.strict_encode64(file_content),
      file_binary:  true,
      started_at:   Time.current
    )

    # Write to a tempfile because the service needs a file path
    require 'tempfile'
    tmp = Tempfile.new(['customer_order_import', '.pdf'], binmode: true)
    tmp.write(file_content)
    tmp.flush

    begin
      result = CustomerOrderImportService.call(tmp.path)

      log.update!(
        status:          'success',
        completed_at:    Time.current,
        records_created: result.created,
        records_updated: result.updated,
        records_skipped: result.skipped,
        warnings:        result.errors.any? ? result.errors.join("\n") : nil
      )

      summary = "Import complete — #{result.created} orders created, #{result.updated} updated."
      summary += " #{result.errors.count} warning(s)." if result.errors.any?
      flash[:notice] = summary
    rescue => e
      log.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
      flash[:alert] = "Import failed: #{e.message}"
    ensure
      tmp.close
      tmp.unlink
    end

    redirect_to new_customer_order_import_path
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_customer_order_import_path, alert: "File not available." if log.file_content.blank?

    send_data Base64.strict_decode64(log.file_content),
              type:        'application/pdf',
              disposition: "attachment; filename=\"#{log.file_name}\""
  end
end
