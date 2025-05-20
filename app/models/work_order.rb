class WorkOrder < ApplicationRecord
  has_many :comments, dependent: :destroy
  belongs_to :workable, polymorphic: true

  validates :subject, presence: true
  validates :status, presence: true
end
