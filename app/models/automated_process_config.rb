class AutomatedProcessConfig < ApplicationRecord
  validates :slug, presence: true, uniqueness: true

  def self.for_slug(slug)
    find_or_create_by!(slug: slug) do |c|
      c.schedule = '0 * * * *'
    end
  end
end
