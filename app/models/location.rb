class Location < ApplicationRecord
  has_rich_text :dispatch_notes
  has_rich_text :location_notes

  has_many :customer_locations
  has_many :customers, through: :customer_locations

  belongs_to :location_category
 
  has_many :location_contacts

  has_many :location_products
  has_many :products, through: :location_products

  has_many :customer_orders

  def city_with_company
    "#{company_name} - #{city}"
  end
  def full_address_with_company
    "#{company_name} - #{address} #{city}, #{state} #{zip}"
  end
  def full_address
    "#{address} #{city}, #{state} #{zip}"
  end
  def has_active_order?
    customer_orders.exists?(order_status: "New")
  end
end
