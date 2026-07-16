class MinMaxImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'Min/Max Import'.freeze

  def new
    @products_with_minmax = Product.where.not(reorder_point: nil).or(Product.where.not(max_stock: nil)).count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    file = params[:file]
    return redirect_to new_min_max_import_path, alert: "Please select a file." unless file
    return redirect_to new_min_max_import_path, alert: "File must be an XLSX file." unless file.original_filename.downcase.end_with?('.xlsx')

    tmp = Tempfile.new(['min_max_import', '.xlsx'], binmode: true)
    tmp.write(file.read)
    tmp.flush
    session[:min_max_import_tmp_path] = tmp.path
    ObjectSpace.undefine_finalizer(tmp)

    @rows            = MinMaxImportService.new(tmp.path).preview
    @update_count    = @rows.count { |r| r.action == :update }
    @skip_no_product = @rows.count { |r| r.action == :skip_no_product }
    @skip_no_values  = @rows.count { |r| r.action == :skip_no_values }
  end

  def create
    unless session[:min_max_import_tmp_path].present? && File.exist?(session[:min_max_import_tmp_path].to_s)
      return redirect_to new_min_max_import_path, alert: "Import session expired. Please re-upload the file."
    end

    file_path = session[:min_max_import_tmp_path]

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      file_name:    File.basename(file_path),
      file_content: Base64.strict_encode64(File.binread(file_path)),
      file_binary:  true,
      started_at:   Time.current
    )

    begin
      result = MinMaxImportService.call(file_path)

      log.update!(
        status:          'success',
        completed_at:    Time.current,
        records_updated: result.updated,
        records_skipped: result.skipped_no_product + result.skipped_no_values,
        warnings:        result.errors.any? ? result.errors.join("\n") : nil
      )

      summary = "Import complete — #{result.updated} products updated with min/max values. " \
                "#{result.skipped_no_product} part numbers not found, " \
                "#{result.skipped_no_values} rows skipped (no values set)."
      summary += " #{result.errors.count} errors." if result.errors.any?

      flash[:notice] = summary
    rescue => e
      log.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
      flash[:alert] = "Import failed: #{e.message}"
    ensure
      File.delete(file_path) rescue nil
      session.delete(:min_max_import_tmp_path)
    end

    redirect_to new_min_max_import_path
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_min_max_import_path, alert: "File not available." if log.file_content.blank?

    send_data Base64.strict_decode64(log.file_content),
              type:        'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
              disposition: "attachment; filename=\"#{log.file_name}\""
  end
end
