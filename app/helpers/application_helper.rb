# frozen_string_literal: true

# View helpers shared across the app: cron labels, sidebar nav links and badges.
module ApplicationHelper
  CRON_PRESETS = {
    'Off' => '',
    'Every 1 minute' => '* * * * *',
    'Every 2 minutes' => '*/2 * * * *',
    'Every 5 minutes' => '*/5 * * * *',
    'Every 15 minutes' => '*/15 * * * *',
    'Every 30 minutes' => '*/30 * * * *',
    'Every hour' => '0 * * * *',
    'Every 2 hours' => '0 */2 * * *',
    'Every 6 hours' => '0 */6 * * *',
    'Every 12 hours' => '0 */12 * * *',
    'Once a day (midnight)' => '0 0 * * *',
    'Once a day (6am)' => '0 6 * * *',
    'Once a week (Sunday midnight)' => '0 0 * * 0'
  }.freeze

  def cron_description(expr)
    CRON_PRESETS.key(expr) || expr
  end

  # Sidebar link (layouts/_sidebar); `active` controls the highlight, `keywords`
  # are extra terms for the sidebar quick-jump search.
  def nav_item(label, path, icon, active: false, keywords: nil)
    sidebar_li(label, path, icon, ('active' if active), keywords)
  end

  # Sidebar link that only shows while the quick-jump search is filtering.
  def nav_search_item(label, path, icon, keywords: nil)
    sidebar_li(label, path, icon, 'sidebar-search-only', keywords)
  end

  def sidebar_li(label, path, icon, css_class, keywords)
    content_tag(:li, class: css_class, data: { keywords: keywords }) do
      link_to(path) { content_tag(:i, '', class: "bi #{icon}") + " #{label}" }
    end
  end

  # Badge for a quote / quote line price lock (:active, :scheduled, :expired, :superseded, :ended).
  def lock_status_badge(status)
    return if status.nil?

    css = { active: 'bg-success', scheduled: 'bg-info text-dark', expired: 'bg-secondary',
            superseded: 'bg-warning text-dark', ended: 'bg-dark' }[status]
    content_tag(:span, "Price lock: #{status.to_s.capitalize}", class: "badge #{css}")
  end

  # Quote margin review status (see QuoteMarginReview::Line#status).
  def margin_status_badge(status)
    label, css = { reprice: %w[Re-price bg-danger], watch: ['Watch', 'bg-warning text-dark'],
                   ok: %w[OK bg-success], unknown: ['No cost', 'bg-secondary'] }[status]
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

  READINESS_COLORS = { green: '#198754', yellow: '#ffc107', red: '#dc3545' }.freeze

  # Green / yellow / red dot for MaterialReadiness, with the reason on hover.
  def readiness_dot(status, label: false)
    return tag.span('—', class: 'text-muted') unless status

    dot = tag.span('', class: 'd-inline-block rounded-circle align-middle', title: status.reason,
                       style: "width:.8rem;height:.8rem;background:#{READINESS_COLORS[status.level]};")
    label ? safe_join([dot, tag.span(status.reason, class: 'small text-muted ms-1')]) : dot
  end

  # Small "Credit" badge for a customer PDI reports over its limit or on credit hold.
  def credit_flag(customer)
    return unless customer&.over_credit?

    available = customer.pdi_available_credit
    limit = customer.pdi_credit_limit
    as_of = customer.pdi_credit_updated_at
    details = [customer.pdi_credit_status, ("available #{number_to_currency(available)}" if available),
               ("limit #{number_to_currency(limit)}" if limit), as_of&.strftime('as of %b %-d %-I:%M %p')]
    tag.span('Credit', class: 'badge bg-danger', style: 'font-size:.65rem;', title: details.compact.join(' · '))
  end

  # Column header that sorts the current list by `column` ("name" → name_asc / name_desc), keeping the
  # filters. Loads the whole page so the filter form's hidden sort field stays in step.
  def sort_header(label, column)
    current = params[:sort].to_s
    direction = current == "#{column}_asc" ? 'desc' : 'asc'
    arrow = { "#{column}_asc" => ' ▲', "#{column}_desc" => ' ▼' }[current]
    query = request.query_parameters.except('page').merge('sort' => "#{column}_#{direction}", 'filtered' => '1')
    link_to "#{label}#{arrow}", "#{request.path}?#{query.to_query}",
            class: 'text-decoration-none text-dark text-nowrap', data: { turbo_frame: '_top' }
  end
end
