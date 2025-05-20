class Comment < ApplicationRecord
  belongs_to :user
  belongs_to :work_order

  validates :content, presence: true
end
