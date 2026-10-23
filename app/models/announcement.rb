class Announcement < ApplicationRecord
  has_rich_text :content

  scope :active, -> { where(status: 'active') }
end
