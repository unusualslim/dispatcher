class Location < ApplicationRecord
  has_rich_text :dispatch_notes
  has_rich_text :location_notes

  belongs_to :customer, class_name: 'User', optional: true
  belongs_to :supplier, class_name: 'User', optional: true
  belongs_to :location_category
 
  has_many :location_contacts

  has_many :location_products
  has_many :products, through: :location_products

  def city_with_company
    "#{company_name} - #{city}"
  end
end
