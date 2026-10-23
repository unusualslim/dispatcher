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

  # Sidebar link (layouts/_sidebar); `active` controls the highlight, `keywords`
  # are extra terms for the sidebar quick-jump search.
  def nav_item(label, path, icon, active: false, keywords: nil, search_only: false)
    classes = [('active' if active), ('sidebar-search-only' if search_only)].compact.join(' ')
    content_tag(:li, class: classes.presence, data: { keywords: keywords }) do
      link_to(path) { content_tag(:i, '', class: "bi #{icon}") + " #{label}" }
    end
  end

  # Badge for a quote / quote line price lock (:active, :scheduled, :expired, :superseded, :ended).
  def lock_status_badge(status)
    return if status.nil?
    css = { active: 'bg-success', scheduled: 'bg-info text-dark', expired: 'bg-secondary', superseded: 'bg-warning text-dark', ended: 'bg-dark' }[status]
    content_tag(:span, "Price lock: #{status.to_s.capitalize}", class: "badge #{css}")
  end

  # Quote margin review status (see QuoteMarginReview::Line#status).
  def margin_status_badge(status)
    label, css = { reprice: ['Re-price', 'bg-danger'], watch: ['Watch', 'bg-warning text-dark'],
                   ok: ['OK', 'bg-success'], unknown: ['No cost', 'bg-secondary'] }[status]
    content_tag(:span, label, class: "badge #{css}")
  end

  # Signed currency, e.g. "+$0.1200" / "-$0.0500".
  def signed_currency(amount, precision: 4)
    return '—' if amount.nil?
    "#{amount.negative? ? '-' : '+'}#{number_to_currency(amount.abs, precision: precision)}"
  end

  def status_badge_class(status)
    case status.to_s
    when 'draft'    then 'bg-secondary'
    when 'sent'     then 'bg-primary'
    when 'accepted' then 'bg-success'
    when 'rejected' then 'bg-danger'
    else 'bg-secondary'
    end
  end
end
