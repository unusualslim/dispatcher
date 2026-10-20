class PdiProductImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'PDI Product Import'.freeze

  def new
    @product_count = Product.count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    file = params[:file]
    return redirect_to new_pdi_product_import_path, alert: "Please select a file." unless file
    return redirect_to new_pdi_product_import_path, alert: "File must be a CSV file." unless file.original_filename.downcase.end_with?('.csv')

    tmp = Tempfile.new(['pdi_product_import', '.csv'])
    tmp.binmode
    tmp.write(file.read)
    tmp.flush
    session[:pdi_product_import_tmp_path] = tmp.path
    session[:pdi_product_import_file_name] = file.original_filename
    ObjectSpace.undefine_finalizer(tmp)

    @rows = PdiProductImportService.new(tmp.path).preview
    @create_count    = @rows.count { |r| r.action == :create }
    @update_count    = @rows.count { |r| r.action == :update }
    @unchanged_count = @rows.count { |r| r.action == :unchanged }
  end

  def create
    unless session[:pdi_product_import_tmp_path].present? && File.exist?(session[:pdi_product_import_tmp_path].to_s)
      return redirect_to new_pdi_product_import_path, alert: "Import session expired. Please re-upload the file."
    end

    file_path = session[:pdi_product_import_tmp_path]
    file_name = session[:pdi_product_import_file_name] || File.basename(file_path)

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      file_name:    file_name,
      file_content: File.read(file_path),
      file_binary:  false,
      started_at:   Time.current
    )

    begin
      result = PdiProductImportService.call(file_path)

      log.update!(
        status:          'success',
        completed_at:    Time.current,
        records_created: result.created,
        records_skipped: result.unchanged,
        warnings:        result.errors.any? ? result.errors.join("\n") : nil
      )

      summary = "Import complete — #{result.created} created, #{result.updated} updated, #{result.unchanged} unchanged."
      summary += " #{result.errors.count} errors." if result.errors.any?

      flash[:notice] = summary
    rescue => e
      log.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
      flash[:alert] = "Import failed: #{e.message}"
    ensure
      File.delete(file_path) rescue nil
      session.delete(:pdi_product_import_tmp_path)
      session.delete(:pdi_product_import_file_name)
    end

    redirect_to new_pdi_product_import_path
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_pdi_product_import_path, alert: "File not available." if log.file_content.blank?

    send_data log.file_content,
              type:        'text/csv',
              disposition: "attachment; filename=\"#{log.file_name}\""
  end
end
