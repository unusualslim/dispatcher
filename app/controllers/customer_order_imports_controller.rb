class CustomerOrderImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'Customer Order Import'.freeze

  def new
    @order_count = CustomerOrder.count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    file = params[:file]
    return redirect_to new_customer_order_import_path, alert: "Please select a file." unless file
    return redirect_to new_customer_order_import_path, alert: "File must be a PDF file." unless file.original_filename.downcase.end_with?('.pdf')

    tmp = Tempfile.new(['customer_order_import', '.pdf'], binmode: true)
    IO.copy_stream(file.tempfile, tmp)
    tmp.flush
    session[:co_import_tmp_path]   = tmp.path
    session[:co_import_file_name]  = file.original_filename
    ObjectSpace.undefine_finalizer(tmp)

    @rows          = CustomerOrderImportService.new(tmp.path).preview
    @create_count  = @rows.count { |r| r.action == :create }
    @update_count  = @rows.count { |r| r.action == :update }
  end

  def create
    unless session[:co_import_tmp_path].present? && File.exist?(session[:co_import_tmp_path].to_s)
      return redirect_to new_customer_order_import_path, alert: "Import session expired. Please re-upload the file."
    end

    file_path = session[:co_import_tmp_path]
    file_name = session[:co_import_file_name] || File.basename(file_path)

    # Encode in 45 KB chunks (multiple of 3 → no mid-stream padding)
    file_content = File.open(file_path, 'rb') do |f|
      buf = +""
      while (chunk = f.read(45_000))
        buf << [chunk].pack("m0")
      end
      buf
    end

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      file_name:    file_name,
      file_content: file_content,
      file_binary:  true,
      started_at:   Time.current
    )

    file_content = nil
    GC.start

    begin
      result = CustomerOrderImportService.call(file_path)

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
      File.delete(file_path) rescue nil
      session.delete(:co_import_tmp_path)
      session.delete(:co_import_file_name)
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
