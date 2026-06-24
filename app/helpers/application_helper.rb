module ApplicationHelper
  CRON_PRESETS = {
    'Every 1 minute'               => '* * * * *',
    'Every 2 minutes'              => '*/2 * * * *',
    'Every 5 minutes'              => '*/5 * * * *',
    'Every 15 minutes'             => '*/15 * * * *',
    'Every 30 minutes'             => '*/30 * * * *',
    'Every hour'                   => '0 * * * *',
    'Every 2 hours'                => '0 */2 * * *',
    'Every 6 hours'                => '0 */6 * * *',
    'Every 12 hours'               => '0 */12 * * *',
    'Once a day (midnight)'        => '0 0 * * *',
    'Once a day (6am)'             => '0 6 * * *',
    'Once a week (Sunday midnight)'=> '0 0 * * 0',
  }.freeze

  def cron_description(expr)
    CRON_PRESETS.key(expr) || expr
  end
end
