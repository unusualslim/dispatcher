namespace :scheduler do
  desc "Check all automated process configs and trigger any that are due — run this every minute via Render cron job"
  task tick: :environment do
    AutomatedProcessesController::PROCESSES.each do |process|
      config = AutomatedProcessConfig.for_slug(process[:slug])
      next unless config.due?

      process[:job].constantize.perform_now
      config.mark_triggered!
      Rails.logger.info "[Scheduler] Triggered #{process[:name]}"
    end
  end
end
