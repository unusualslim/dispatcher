class Dispatch < ApplicationRecord
    has_and_belongs_to_many :customer_orders

    enum status: { new: "New", sent_to_driver: "Sent to Driver", complete: "Complete", billed: "Billed" }
end
