class DispatchCustomerOrder < ApplicationRecord
  belongs_to :dispatch
  belongs_to :customer_order
end
