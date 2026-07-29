class UserFavorite < ApplicationRecord
  belongs_to :user

  validates :label, presence: true
  validates :path,  presence: true
  validates :path,  uniqueness: { scope: :user_id }

  default_scope { order(:position, :created_at) }
end
