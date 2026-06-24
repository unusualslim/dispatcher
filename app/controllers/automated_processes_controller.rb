class AutomatedProcessesController < ApplicationController
  before_action :require_admin!

  PROCESSES = [
    { name: 'PDI Vendor Sync', job: 'PdiVendorSyncJob', description: 'Syncs vendor list from PDI FTP (AP Vendor List.csv)', schedule: 'Hourly' }
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
    @process_name = params[:id].tr('-', ' ').titleize
    @logs = SyncLog.for_process(@process_name).paginate(page: params[:page], per_page: 25)
  end

  def trigger
    process_name = params[:id].tr('-', ' ').titleize
    process = PROCESSES.find { |p| p[:name] == process_name }
    return redirect_to automated_processes_path, alert: "Unknown process." unless process

    process[:job].constantize.perform_later
    redirect_to automated_process_path(params[:id]), notice: "#{process_name} triggered."
  end
end
