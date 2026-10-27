class PdiInvoiceDateImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = 'PDI Invoice Date Import'.freeze

  def new
    @missing = CustomerOrder.where(order_status: FinancialDashboard::Snapshot::BILLED, invoice_date: nil)
                            .where.not(external_order_no: nil).count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    file = params[:file]
    return redirect_to new_pdi_invoice_date_import_path, alert: t('.choose_csv') unless csv?(file)

    path = save_upload(file)
    @summary = PdiInvoiceDateImportService.new(path).summary
  rescue ArgumentError, CSV::MalformedCSVError => e
    redirect_to new_pdi_invoice_date_import_path, alert: e.message
  end

  def create
    path = session[:pdi_invoice_import_tmp_path].to_s
    return redirect_to new_pdi_invoice_date_import_path, alert: t('.expired') unless path.present? && File.exist?(path)

    run_import(path)
    redirect_to new_pdi_invoice_date_import_path
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_pdi_invoice_date_import_path, alert: t('.unavailable') if log.file_content.blank?

    send_data log.file_content, type: 'text/csv', disposition: "attachment; filename=\"#{log.file_name}\""
  end

  private

  def csv?(file)
    file&.original_filename.to_s.downcase.end_with?('.csv')
  end

  # Keeps the upload until the import is confirmed.
  def save_upload(file)
    tmp = Tempfile.new(['pdi_invoice_dates', '.csv'])
    tmp.binmode
    tmp.write(file.read)
    tmp.flush
    ObjectSpace.undefine_finalizer(tmp)
    session[:pdi_invoice_import_tmp_path] = tmp.path
    session[:pdi_invoice_import_file_name] = file.original_filename
    tmp.path
  end

  def run_import(path)
    log = start_log(path)
    updated = PdiInvoiceDateImportService.new(path).import!
    log.update!(status: 'success', completed_at: Time.current, records_updated: updated)
    flash[:notice] = t('pdi_invoice_date_imports.create.done', count: updated)
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    flash[:alert] = t('pdi_invoice_date_imports.create.failed', message: e.message)
  ensure
    clear_upload(path)
  end

  def start_log(path)
    SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current, file_binary: false,
                    file_name: session[:pdi_invoice_import_file_name], file_content: File.read(path))
  end

  def clear_upload(path)
    FileUtils.rm_f(path)
    session.delete(:pdi_invoice_import_tmp_path)
    session.delete(:pdi_invoice_import_file_name)
  end
end
