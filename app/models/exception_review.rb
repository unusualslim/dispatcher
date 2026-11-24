# Someone dealt with an exception on a review page (Standard Cost Exceptions, more to come). An exception stays
# off the "needs review" list while a review with its kind, subject and fingerprint exists.
class ExceptionReview < ApplicationRecord
  belongs_to :reviewed_by, class_name: 'User', optional: true

  validates :kind, :subject_key, :resolution, :reviewed_at, presence: true

  def self.lookup(kind)
    where(kind: kind).includes(:reviewed_by).index_by { |r| [r.subject_key, r.fingerprint] }
  end

  def self.record!(kind:, subject_key:, fingerprint:, resolution:, user:)
    raise ArgumentError, I18n.t('exception_reviews.resolution_required') if resolution.blank?

    review = find_or_initialize_by(kind: kind, subject_key: subject_key, fingerprint: fingerprint.to_s)
    review.update!(resolution: resolution.strip, reviewed_by: user, reviewed_at: Time.current)
    review
  end
end
