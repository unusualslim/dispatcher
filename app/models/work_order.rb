class WorkOrder < ApplicationRecord
  belongs_to :workable, polymorphic: true

  validates :subject, presence: true
  validates :status, presence: true
end
