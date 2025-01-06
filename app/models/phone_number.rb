class PhoneNumber < ApplicationRecord
  belongs_to :customer

  validates :number, presence: true, unless: :customer_has_phone_numbers?

  def customer_has_phone_numbers?
    customer.phone_numbers.any?
  end
end