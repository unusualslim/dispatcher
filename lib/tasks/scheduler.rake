namespace :scheduler do
  desc 'Check all automated process configs and trigger any that are due — run this every minute via Render cron job'
  task tick: :environment do
    AutomatedProcessesController::PROCESSES.each do |process|
      config = AutomatedProcessesController.config_for(process)
      next unless config.due?

      config.mark_triggered!
      Rails.logger.info "[Scheduler] Triggering #{process[:name]}"
      process[:job].constantize.perform_now
    rescue StandardError => e
      Rails.logger.error "[Scheduler] #{process[:name]} failed: #{e.message}"
    end
  end
end
