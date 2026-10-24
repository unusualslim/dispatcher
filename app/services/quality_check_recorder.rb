# Records a production order's quality check results against its product's specs.
# Numeric results may carry a detection-limit qualifier ("< 0.5", ">60"); pass/fail results come in
# as "pass" or "fail". Blank entries are skipped; re-entering a check updates it. Returns the count saved.
class QualityCheckRecorder
  NUMERIC = /\A\s*([<>])?\s*(-?\d+(?:\.\d+)?|-?\.\d+)\s*\z/

  def initialize(order, user)
    @order = order
    @user = user
  end

  def record!(results)
    specs = @order.product&.quality_specs&.index_by { |s| s.id.to_s } || {}
    QualityResult.transaction do
      results.count { |spec_id, attrs| record_one!(specs[spec_id.to_s], attrs) }
    end
  end

  private

  def record_one!(spec, attrs)
    reading = spec && parse(spec, attrs[:value])
    reading && save!(spec, reading.merge(notes: attrs[:notes].presence))
  end

  def parse(spec, raw)
    raw = raw.to_s.strip
    return nil if raw.empty?
    return { passed: raw.casecmp?('pass') } if spec.pass_fail?

    match = raw.match(NUMERIC)
    match ? { qualifier: match[1], value: match[2] } : { value: raw } # non-numbers fail validation
  end

  def save!(spec, reading)
    result = @order.quality_results.find_or_initialize_by(quality_spec: spec)
    result.update!(QualityResult.copy_spec(spec).merge(qualifier: nil, value: nil, passed: nil)
                                .merge(reading).merge(tested_by: @user, tested_at: Time.current))
  end
end
