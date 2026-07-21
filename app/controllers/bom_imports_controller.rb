class BomImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'BOM Import'.freeze

  def new
    @existing_count = ProductComponent.count
    @product_count  = Product.joins(:product_components).distinct.count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    file = params[:file]
    return redirect_to new_bom_import_path, alert: "Please select a file." unless file
    return redirect_to new_bom_import_path, alert: "File must be a CSV file." unless file.original_filename.downcase.end_with?('.csv')

    tmp = Tempfile.new(['bom_import', '.csv'])
    tmp.binmode
    tmp.write(file.read)
    tmp.flush
    session[:bom_import_tmp_path] = tmp.path
    session[:bom_import_overwrite] = params[:overwrite] == '1'
    ObjectSpace.undefine_finalizer(tmp)

    @overwrite = session[:bom_import_overwrite]
    @rows = BomImportService.new(tmp.path, overwrite: @overwrite).preview
    @create_count    = @rows.count { |r| r.action == :create }
    @overwrite_count = @rows.count { |r| r.action == :overwrite }
    @skip_no_product = @rows.count { |r| r.action == :skip_no_product }
    @skip_has_bom    = @rows.count { |r| r.action == :skip_has_bom }
  end

  def create
    unless session[:bom_import_tmp_path].present? && File.exist?(session[:bom_import_tmp_path].to_s)
      return redirect_to new_bom_import_path, alert: "Import session expired. Please re-upload the file."
    end

    file_path = session[:bom_import_tmp_path]
    file_name = File.basename(file_path)

    log = SyncLog.create!(
      process_name: PROCESS_NAME,
      status:       'running',
      file_name:    file_name,
      file_content: File.read(file_path),
      file_binary:  false,
      started_at:   Time.current
    )

    overwrite = session[:bom_import_overwrite] || false

    begin
      result = BomImportService.call(file_path, overwrite: overwrite)

      log.update!(
        status:          'success',
        completed_at:    Time.current,
        records_created: result.created,
        records_skipped: result.skipped_no_product + result.skipped_already_has_bom,
        warnings:        result.errors.any? ? result.errors.join("\n") : nil
      )

      summary = "Import complete — #{result.created} components created"
      summary += ", #{result.overwritten} BOMs overwritten" if result.overwritten > 0
      summary += ". #{result.skipped_no_product} products not found" if result.skipped_no_product > 0
      summary += ", #{result.skipped_already_has_bom} already had a BOM (skipped)" if result.skipped_already_has_bom > 0
      summary += "."
      summary += " #{result.errors.count} warnings." if result.errors.any?

      flash[:notice] = summary
    rescue => e
      log.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
      flash[:alert] = "Import failed: #{e.message}"
    ensure
      File.delete(file_path) rescue nil
      session.delete(:bom_import_tmp_path)
      session.delete(:bom_import_overwrite)
    end

    redirect_to new_bom_import_path
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_bom_import_path, alert: "File not available." if log.file_content.blank?

    send_data log.file_content,
              type:        'text/csv',
              disposition: "attachment; filename=\"#{log.file_name}\""
  end
end
