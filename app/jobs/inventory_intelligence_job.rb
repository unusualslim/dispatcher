class InventoryIntelligenceJob < ApplicationJob
  queue_as :default

  # report_type: :daily or :weekly
  def perform(report_type = :daily)
    report_type = report_type.to_sym
    report = InventoryIntelligenceService.new(report_type: report_type).run

    recipients = User.active.where(role: %w[admin manager]).where(email_opt_in: true)

    recipients.each do |user|
      case report_type
      when :daily
        InventoryIntelligenceMailer.daily_report(user, report).deliver_now
      when :weekly
        InventoryIntelligenceMailer.weekly_report(user, report).deliver_now
      end
    end

    Rails.logger.info "[InventoryIntelligence] #{report_type} report sent to #{recipients.count} recipient(s). " \
                      "Critical: #{report.critical_items.size}, Low: #{report.low_items.size}, " \
                      "Recommendations: #{report.recommendations.size}"
  end
end
