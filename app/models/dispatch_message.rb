class DispatchMessage < ApplicationRecord
    belongs_to :user
    belongs_to :dispatch
  
    validates :message_body, presence: true
    validates :delivery_method, presence: true
  end  