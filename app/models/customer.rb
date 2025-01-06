class Customer < ApplicationRecord
    has_many :phone_numbers, dependent: :destroy
    accepts_nested_attributes_for :phone_numbers, allow_destroy: true
    has_many :customer_locations
    has_many :customer_orders, dependent: :destroy
    has_many :locations, through: :customer_locations

    validates :email, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true }
    
    validates :preferred_contact_method, inclusion: { in: ['no preference', 'phone', 'email'] }
end
