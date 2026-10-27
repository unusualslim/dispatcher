module FinancialDashboardsHelper
  # Change from a comparison period, with an arrow and a word so it never relies on color alone.
  # kind: :percent (relative change), :days or :points (absolute); higher_is_better flips the coloring
  # (nil: neutral, no color).
  def dashboard_change(current, previous, kind: :percent, higher_is_better: true)
    return tag.span('—', class: 'text-muted') if current.nil? || previous.nil?

    delta = change_amount(current, previous, kind)
    return tag.span('n/a', class: 'text-muted', title: 'Nothing in the comparison period') if delta.nil?
    return tag.span('no change', class: 'text-muted') if delta.round(1).zero?

    change_tag(delta, kind, higher_is_better)
  end

  # A comparison table row: this period, prior month, change, last year, change.
  # format: :currency, :days, :percent (a share), or :number; opts go to dashboard_change.
  def dashboard_row(label, values, format: :currency, **opts)
    current = tag.td(dashboard_value(values[:current], format), class: 'text-end fw-semibold')
    comparisons = %i[prior_month last_year].map { |period| comparison_cells(values, period, format, opts) }
    tag.tr(safe_join([tag.td(label), current, *comparisons]))
  end

  def dashboard_value(value, format)
    return tag.span('—', class: 'text-muted') if value.nil?

    case format
    when :currency then number_to_currency(value, precision: 0)
    when :days then "#{number_with_precision(value, precision: 1)} days"
    when :percent then number_to_percentage(value * 100, precision: 0)
    else number_with_delimiter(value.to_d.round)
    end
  end

  def dashboard_range(range)
    "#{range.begin.strftime('%b %-d')} – #{range.end.strftime('%b %-d, %Y')}"
  end

  private

  def comparison_cells(values, period, format, opts)
    safe_join([tag.td(dashboard_value(values[period], format), class: 'text-end'),
               tag.td(dashboard_change(values[:current], values[period], **opts), class: 'text-end small')])
  end

  def change_tag(delta, kind, higher_is_better)
    tag.span(class: change_class(delta, higher_is_better)) do
      safe_join([tag.i(class: "bi bi-arrow-#{delta.positive? ? 'up' : 'down'}-short"), change_label(delta, kind)])
    end
  end

  def change_class(delta, higher_is_better)
    return 'text-body-secondary' if higher_is_better.nil?

    delta.positive? == higher_is_better ? 'text-success' : 'text-danger'
  end

  def change_amount(current, previous, kind)
    return current - previous unless kind == :percent
    return nil if previous.zero?

    (current - previous) / previous.abs * 100
  end

  def change_label(delta, kind)
    case kind
    when :days then "#{number_with_precision(delta.abs, precision: 1)} days"
    when :points then "#{number_with_precision(delta.abs * 100, precision: 1)} pts"
    else number_to_percentage(delta.abs, precision: 1)
    end
  end
end
