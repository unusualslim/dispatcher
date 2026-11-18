# Why product or material was scrapped on a production order (Production → Scrap Reasons; add as needed, retire by
# making inactive so past entries keep their reason).
class ScrapReason < ApplicationRecord
  include Audited

  audited

  has_many :production_order_scraps, dependent: :restrict_with_error

  validates :name, presence: true, uniqueness: { case_sensitive: false }

  scope :active, -> { where(active: true) }
  scope :ordered, -> { order(:position, :name) }
end
