class AutomatedProcessesController < ApplicationController
  before_action :require_admin!

  PROCESSES = [
    { slug: 'pdi-vendor-sync', name: 'PDI Vendor Sync', job: 'PdiVendorSyncJob', description: 'Syncs vendor list from PDI FTP (AP Vendor List.csv)', schedule: 'Hourly' }
  ].freeze

  def index
    @processes = PROCESSES.map do |p|
      logs = SyncLog.for_process(p[:name])
      p.merge(
        last_run: logs.first,
        run_count: logs.count,
        success_count: logs.where(status: 'success').count,
        failed_count: logs.where(status: 'failed').count
      )
    end
  end

  def show
    @process = find_process!
    @logs = SyncLog.for_process(@process[:name]).paginate(page: params[:page], per_page: 25)
  end

  def trigger
    @process = find_process!
    @process[:job].constantize.perform_later
    redirect_to automated_process_path(params[:id]), notice: "#{@process[:name]} triggered."
  end

  private

  def find_process!
    process = PROCESSES.find { |p| p[:slug] == params[:id] }
    redirect_to automated_processes_path, alert: "Unknown process." unless process
    process
  end
end
