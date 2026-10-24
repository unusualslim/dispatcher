# A quality test a product's production orders must record: numeric against a target range
# (e.g. pH 9.5 to 10.5) or pass/fail against an expected description (e.g. Appearance "clear").
class QualitySpec < ApplicationRecord
  RESULT_TYPES = { 'numeric' => 'Numeric', 'pass_fail' => 'Pass/Fail' }.freeze

  belongs_to :product
  has_many :quality_results, dependent: :nullify

  validates :name, presence: true
  validates :result_type, inclusion: { in: RESULT_TYPES.keys }
  validate :range_in_order

  def pass_fail?
    result_type == 'pass_fail'
  end

  def target_label
    QualitySpec.target_label(self)
  end

  # Works for specs and results (both carry the copied fields).
  def self.target_label(check)
    return check.expected.presence || 'Pass' if check.result_type == 'pass_fail'

    [range_label(check.target_min, check.target_max), check.unit.presence].compact.join(' ')
  end

  # Certificate-of-analysis wording: "9.5 – 10.5", "99 Min", "0.6 Max", "Report" (no limit).
  def self.range_label(min, max)
    return "#{format_number(min)} – #{format_number(max)}" if min && max
    return "#{format_number(min)} Min" if min
    return "#{format_number(max)} Max" if max

    'Report'
  end

  def self.format_number(value)
    value.to_d.to_s('F').sub(/\.0+\z/, '').sub(/(\.\d*?)0+\z/, '\1')
  end

  private

  def range_in_order
    errors.add(:target_max, 'must be at least the minimum') if target_min && target_max && target_max < target_min
  end
end
