# Preview all emails at http://localhost:3000/rails/mailers/inventory_intelligence_mailer
class InventoryIntelligenceMailerPreview < ActionMailer::Preview
  def daily_report
    report = InventoryIntelligenceService.new(report_type: :daily).run
    user = User.where(role: 'admin').first
    InventoryIntelligenceMailer.daily_report(user, report)
  end

  def weekly_report
    report = InventoryIntelligenceService.new(report_type: :weekly).run
    user = User.where(role: 'admin').first
    InventoryIntelligenceMailer.weekly_report(user, report)
  end
end
