class Dispatch < ApplicationRecord
    before_validation :set_default_status, on: :create
    before_save :set_full_destination_address
    #belongs_to :customer_order
    has_many :dispatch_customer_order, dependent: :destroy
    has_many :customer_orders, through: :dispatch_customer_order
    has_many_attached :files
    belongs_to :driver, class_name: 'User', foreign_key: 'driver_id', optional: true
    belongs_to :vendor, optional: true
    belongs_to :destination_location, class_name: "Location", foreign_key: "destination_location_id", optional: true
    enum dispatch_status: { New: "New", sent_to_driver: "Sent to Driver", complete: "Complete", billed: "Billed", deleted: "Deleted" }

    def freight_only?
      customer_orders.exists?(freight_only: true)
    end

    private

    def set_full_destination_address
      if destination_location.present?
        self.destination = "#{destination_location.address}, #{destination_location.city}, #{destination_location.state} #{destination_location.zip}"
      end
    end

    def set_default_status
      self.dispatch_status = 'New'
    end
end
