module ApplicationHelper
  CRON_DESCRIPTIONS = {
    '0 * * * *'   => 'every hour',
    '*/30 * * * *' => 'every 30 minutes',
    '0 */2 * * *' => 'every 2 hours',
    '0 0 * * *'   => 'daily at midnight',
    '0 6 * * *'   => 'daily at 6am',
    '0 0 * * 0'   => 'weekly on Sunday',
  }.freeze

  def cron_description(expr)
    CRON_DESCRIPTIONS[expr] || expr
  end
end
