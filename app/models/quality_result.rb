# A recorded quality check on a production order. Out-of-range results don't block completion;
# they wait for someone with Production approval to review them and record a resolution.
class QualityResult < ApplicationRecord
  COPIED_FIELDS = %i[section name test_method result_type expected unit target_min target_max].freeze

  belongs_to :production_order
  belongs_to :quality_spec, optional: true
  belongs_to :tested_by, class_name: 'User', optional: true
  belongs_to :reviewed_by, class_name: 'User', optional: true

  validates :name, :tested_at, presence: true
  validates :value, numericality: true, unless: :pass_fail?
  validates :passed, inclusion: { in: [true, false] }, if: :pass_fail?
  validates :qualifier, inclusion: { in: ['<', '>'] }, allow_nil: true
  before_validation :set_in_range

  scope :out_of_range, -> { where(in_range: false) }
  scope :unreviewed, -> { where(reviewed_at: nil) }

  def self.copy_spec(spec)
    spec.slice(*COPIED_FIELDS).merge(quality_spec: spec)
  end

  def pass_fail?
    result_type == 'pass_fail'
  end

  def target_label
    QualitySpec.target_label(self)
  end

  # As reported, e.g. "< 0.5 mg/kg", "9.8", "Pass".
  def display_value
    return passed ? 'Pass' : 'Fail' if pass_fail?

    [qualifier, QualitySpec.format_number(value), unit.presence].compact.join(' ')
  end

  def reviewed?
    reviewed_at.present?
  end

  def review!(user, resolution)
    raise ArgumentError, 'Describe the resolution' if resolution.to_s.strip.blank?

    update!(reviewed_by: user, reviewed_at: Time.current, resolution: resolution.strip)
  end

  private

  # Limits are inclusive, so "< 0.5" against a max of 0.5 is in range.
  def set_in_range
    self.in_range = pass_fail? ? passed == true : value_within_target?
  end

  def value_within_target?
    value.present? && (target_min.nil? || value >= target_min) && (target_max.nil? || value <= target_max)
  end
end
