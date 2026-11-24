# Tags that show what a planning number rests on that isn't a recorded fact (Planning::Assumption), and the
# page-level summary linking to Purchasing → Planning Assumptions, where the data behind them gets fixed.
module AssumptionsHelper
  TAG_CLASS = 'badge rounded-pill bg-warning-subtle text-warning-emphasis border border-warning-subtle ' \
              'fw-normal me-1'.freeze

  def assumption_tags(assumptions)
    return if assumptions.blank?

    safe_join(assumptions.map { |a| tag.span(a.label, class: TAG_CLASS, title: a.detail, data: { assumption: a.key }) })
  end

  # "9 of 11 lines rest on assumptions" with a link to fix them; nothing when every row is based on facts.
  def assumption_summary(rows, noun: 'line')
    count = rows.count { |r| r.assumptions.present? }
    return if count.zero?

    tag.div(class: 'alert alert-warning py-2 small d-flex flex-wrap gap-2 align-items-center') do
      safe_join([tag.i(class: 'bi bi-exclamation-triangle'),
                 tag.span("#{count} of #{pluralize(rows.size, noun)} rest on assumptions " \
                          '(defaults or guesses, tagged below). Hover a tag for why.'),
                 link_to('See what to fix', planning_assumptions_path, class: 'alert-link')])
    end
  end
end
