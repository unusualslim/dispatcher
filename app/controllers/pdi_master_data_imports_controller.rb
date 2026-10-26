# Manual run of the PDI master data sync: fetch from the web service, preview the changes, confirm.
class PdiMasterDataImportsController < ApplicationController
  before_action :require_admin!

  PROCESS_NAME = PdiMasterDataSyncJob::PROCESS_NAME

  def new
    @configured = PdiWebService.configured?
    @linked_customers = Customer.where.not(pdi_customer_id: nil).count
    @linked_ship_tos = CustomerLocation.where.not(pdi_location_id: nil).count
    @linked_terminals = Location.where.not(pdi_terminal_id: nil).count
    @logs = SyncLog.for_process(PROCESS_NAME).limit(20)
  end

  def preview
    xml = PdiWebService.new.master_data
    session[:pdi_master_data_tmp_path] = save_tmp(xml)
    @result = PdiMasterDataImportService.new(xml).preview
  rescue *PdiWebService::FAILURES => e
    redirect_to new_pdi_master_data_import_path, alert: t('.fetch_failed', error: e.message)
  end

  def create
    path = session.delete(:pdi_master_data_tmp_path).to_s
    return redirect_to new_pdi_master_data_import_path, alert: t('.expired') unless path.present? && File.exist?(path)

    import(File.read(path))
    redirect_to new_pdi_master_data_import_path
  ensure
    FileUtils.rm_f(path) if path.present?
  end

  def download
    log = SyncLog.find(params[:log_id])
    return redirect_to new_pdi_master_data_import_path, alert: t('.unavailable') if log.file_content.blank?

    send_data Base64.strict_decode64(log.file_content), type: 'application/gzip',
                                                        disposition: "attachment; filename=\"#{log.file_name}\""
  end

  private

  def save_tmp(xml)
    tmp = Tempfile.new(['pdi_master_data', '.xml'])
    tmp.write(xml)
    tmp.flush
    ObjectSpace.undefine_finalizer(tmp)
    tmp.path
  end

  def import(xml)
    log = SyncLog.create!(process_name: PROCESS_NAME, status: 'running', started_at: Time.current)
    flash[:notice] = import_notice(PdiMasterDataSyncJob.import(xml, log))
  rescue StandardError => e
    log&.update!(status: 'failed', completed_at: Time.current, error_message: e.message)
    flash[:alert] = t('pdi_master_data_imports.create.failed', error: e.message)
  end

  def import_notice(result)
    t('pdi_master_data_imports.create.imported', summary: PdiMasterDataSyncJob.summary(result).tr("\n", ';'),
                                                 errors: result.errors.size)
  end
end
