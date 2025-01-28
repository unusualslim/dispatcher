class DispatchMessage < ApplicationRecord
    belongs_to :user
  
    validates :message_body, presence: true
    validates :delivery_method, presence: true
  end  