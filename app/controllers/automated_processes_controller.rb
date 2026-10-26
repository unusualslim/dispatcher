require 'base64'

class AutomatedProcessesController < ApplicationController
  before_action :require_admin!

  PROCESSES = [
    { slug: 'pdi-order-sync',   name: 'PDI Order Sync',   job: 'PdiOrderSyncJob',
      description: 'Syncs customer orders from PDI FTP (Loadntrucks-Order-Export.pdf)', default_schedule: '*/15 * * * *' },
    { slug: 'pdi-vendor-sync',  name: 'PDI Vendor Sync',  job: 'PdiVendorSyncJob',
      description: 'Syncs vendor list from PDI FTP (AP Vendor List.csv)' },
    { slug: 'pdi-product-sync', name: 'PDI Product Sync', job: 'PdiProductSyncJob',
      description: 'Syncs product inventory from PDI FTP (LoadNTrucks-CurrentInventory.xls)' },
    { slug: 'pdi-po-sync',      name: 'PDI Purchase Order Sync', job: 'PdiPurchaseOrderSyncJob',
      description: 'Imports purchase orders from PDI FTP (Warehouse Transaction Report.xls)' },
    { slug: 'pdi-fuel-inventory-sync', name: PdiFuelInventorySyncJob::PROCESS_NAME, job: 'PdiFuelInventorySyncJob',
      description: 'Syncs fuel tank stock by product and site from PDI FTP (FI Inventory Report.xls)',
      default_schedule: '0 6 * * *' },
    { slug: 'pdi-gl-export', name: PdiGlExport::PROCESS_NAME, job: 'PdiGlExportJob',
      description: 'Posts completed production orders\' FPST journals and uploads pending GL entries to PDI FTP' },
    { slug: 'pdi-master-data-sync', name: PdiMasterDataSyncJob::PROCESS_NAME, job: 'PdiMasterDataSyncJob',
      description: 'Syncs customers, ship-tos, terminals and products from the PDI web service (GetMasterData). ' \
                   'Off until scheduled; review the first run at Data Imports → PDI Master Data.',
      default_schedule: '' },
    { slug: 'pdi-order-api-sync', name: PdiOrderApiSyncJob::PROCESS_NAME, job: 'PdiOrderApiSyncJob',
      description: 'Imports fuel and warehouse orders from the PDI web service and re-checks open orders\' ' \
                   'status (replaces the FTP orders.xls sync). Off until scheduled.',
      default_schedule: '' }
  ].freeze

  # A process's schedule; new configs start at its default_schedule (blank = off), else hourly.
  def self.config_for(process)
    AutomatedProcessConfig.for_slug(process[:slug], default_schedule: process.fetch(:default_schedule, '0 * * * *'))
  end

  def index
    @processes = PROCESSES.map do |p|
      logs   = SyncLog.for_process(p[:name])
      config = self.class.config_for(p)
      p.merge(
        config: config,
        last_run: logs.first,
        run_count: logs.count,
        success_count: logs.where(status: 'success').count,
        failed_count: logs.where(status: 'failed').count
      )
    end
  end

  def show
    @process = find_process!
    @config  = self.class.config_for(@process)
    @logs    = SyncLog.for_process(@process[:name]).paginate(page: params[:page], per_page: 25)
  end

  def update_config
    process = find_process!
    config  = self.class.config_for(process)
    config.update!(config_params)
    redirect_to automated_process_path(params[:id]), notice: 'Schedule updated.'
  end

  def trigger
    process = find_process!
    process[:job].constantize.perform_later
    redirect_to automated_process_path(params[:id]), notice: "#{process[:name]} triggered."
  end

  def download_file
    log = SyncLog.find(params[:log_id])
    return redirect_to automated_process_path(params[:id]), alert: 'File not available.' if log.file_content.blank?

    if log.file_binary?
      send_data Base64.strict_decode64(log.file_content),
                type: 'application/octet-stream',
                disposition: "attachment; filename=\"#{log.file_name}\""
    else
      send_data log.file_content,
                type: 'text/csv',
                disposition: "attachment; filename=\"#{log.file_name || 'export.csv'}\""
    end
  end

  private

  def find_process!
    process = PROCESSES.find { |p| p[:slug] == params[:id] }
    redirect_to automated_processes_path, alert: 'Unknown process.' unless process
    process
  end

  def config_params
    params.require(:automated_process_config).permit(:schedule, :notes)
  end
end
