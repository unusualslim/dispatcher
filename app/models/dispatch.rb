class Dispatch < ApplicationRecord
    before_validation :set_default_status, on: :create
    #belongs_to :customer_order
    has_many :dispatch_customer_order, dependent: :destroy
    has_many :customer_orders, through: :dispatch_customer_order
    belongs_to :driver, class_name: 'User', foreign_key: 'driver_id', optional: true
    enum dispatch_status: { New: "New", sent_to_driver: "Sent to Driver", complete: "Complete", billed: "Billed", deleted: "Deleted" }

    private

    def set_default_status
      self.dispatch_status = 'New'
    end
end
