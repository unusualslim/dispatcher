class InventoryIntelligenceMailer < ApplicationMailer
  default from: 'noreply@loadntrucks.com'

  def daily_report(user, report)
    @user   = user
    @report = report
    mail(
      to: user.email,
      subject: daily_subject(report)
    )
  end

  def weekly_report(user, report)
    @user   = user
    @report = report
    mail(
      to: user.email,
      subject: "Weekly Inventory Intelligence Report — #{Date.today.strftime('%b %d, %Y')}"
    )
  end

  private

  def daily_subject(report)
    critical = report.critical_items.size
    prefix = if critical > 0
               "\u26a0\ufe0f #{critical} Critical"
             else
               "\u2705 All Clear"
             end
    "#{prefix} — Daily Inventory Report #{Date.today.strftime('%b %d')}"
  end
end
