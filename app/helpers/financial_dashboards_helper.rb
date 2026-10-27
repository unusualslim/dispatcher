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

  def dashboard_range(range)
    "#{range.begin.strftime('%b %-d')} – #{range.end.strftime('%b %-d, %Y')}"
  end

  private

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
