class Announcement < ApplicationRecord
    scope :active, -> { where(status: 'active') }
end
