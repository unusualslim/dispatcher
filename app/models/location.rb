class Location < ApplicationRecord
  has_rich_text :dispatch_notes
  has_rich_text :location_notes

  belongs_to :customer, class_name: 'User', optional: true
  belongs_to :supplier, class_name: 'User', optional: true
  has_and_belongs_to_many :location_categories
  has_many :location_contacts
end
