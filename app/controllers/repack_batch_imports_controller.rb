class RepackBatchImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'Repack Batch Import'.freeze

  def new
    @production_order_count = ProductionOrder.count
    @pdi_count = ProductionOrder.where("number LIKE 'PDI-%'").count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    file = params[:file]
    return redirect_to new_repack_batch_import_path, alert: 'Please select a file.' unless file

    unless file.original_filename.downcase.end_with?('.csv')
      return redirect_to new_repack_batch_import_path,
                         alert: 'File must be a CSV file.'
    end

    tmp = Tempfile.new(['repack_batch_import', '.csv'])
    tmp.binmode
    tmp.write(file.read)
    tmp.flush
    session[:repack_batch_import_tmp_path] = tmp.path
    session[:repack_batch_import_file_name] = file.original_filename
    ObjectSpace.undefine_finalizer(tmp)

    @rows = RepackBatchImportService.new(tmp.path).preview
    @create_count       = @rows.count { |r| r.action == :create }
    @skip_exists_count  = @rows.count { |r| r.action == :skip_exists }
    @skip_reversed_count = @rows.count { |r| r.action == :skip_reversed }
    @skip_no_product_count = @rows.count { |r| r.action == :skip_no_product }
  end

  def create
    unless session[:repack_batch_import_tmp_path].present? && File.exist?(session[:repack_batch_import_tmp_path].to_s)
      return redirect_to new_repack_batch_import_path, alert: 'Import session expired. Please re-upload the file.'
    end

    file_path = session[:repack_batch_import_tmp_path]
    file_name = session[:repack_batch_import_file_name] || File.basename(file_path)

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status: 'running',
      file_name: file_name,
      file_binary: false,
      started_at: Time.current
    )

    begin
      result = RepackBatchImportService.call(file_path)

      log.update!(
        status: 'success',
        completed_at: Time.current,
        records_created: result.created,
        records_skipped: result.skipped_exists + result.skipped_reversed + result.skipped_no_product,
        warnings: result.errors.any? ? result.errors.join("\n") : nil
      )

      summary = "Import complete — #{result.created} production orders created."
      summary += " #{result.skipped_exists} already imported." if result.skipped_exists > 0
      summary += " #{result.skipped_reversed} reversed batches skipped." if result.skipped_reversed > 0
      summary += " #{result.skipped_no_product} skipped (product not found)." if result.skipped_no_product > 0
      summary += " #{result.errors.count} warnings." if result.errors.any?

      flash[:notice] = summary
    rescue StandardError => e
      log.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
      flash[:alert] = "Import failed: #{e.message}"
    ensure
      File.delete(file_path) rescue nil
      session.delete(:repack_batch_import_tmp_path)
      session.delete(:repack_batch_import_file_name)
    end

    redirect_to new_repack_batch_import_path
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_repack_batch_import_path, alert: 'File not available.' if log.file_content.blank?

    send_data log.file_content,
              type: 'text/csv',
              disposition: "attachment; filename=\"#{log.file_name}\""
  end
end
