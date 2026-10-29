class Dispatch < ApplicationRecord
  before_validation :set_default_status, on: :create
  before_validation :link_origin_location, if: -> { origin_changed? || (origin_location_id.nil? && origin.present?) }
  before_save :set_full_destination_address
  # belongs_to :customer_order
  has_many :dispatch_customer_order, dependent: :destroy
  has_many :customer_orders, through: :dispatch_customer_order
  has_many :dispatch_messages, dependent: :destroy
  has_many_attached :files
  belongs_to :driver, class_name: 'User', optional: true
  belongs_to :vendor, optional: true
  belongs_to :truck, class_name: 'Thing', optional: true
  belongs_to :trailer, class_name: 'Thing', optional: true
  has_many :things
  belongs_to :destination_location, class_name: 'Location', optional: true
  # The origin terminal. `origin` keeps the text picked on the form (a snapshot of the terminal's name and address).
  belongs_to :origin_location, class_name: 'Location', optional: true
  has_many :order_freight_charges, dependent: :nullify
  has_many :freight_payables, as: :source, dependent: :destroy
  # Not a database column (the real status lives in `status`); declared so Rails 7.1+
  # accepts the enum. Behaves as before: in-memory only, never saved.
  attribute :dispatch_status, :string
  enum :dispatch_status, { New: 'New', sent_to_driver: 'Sent to Driver', complete: 'Complete', billed: 'Billed',
                           deleted: 'Deleted' }

  def freight_only?
    customer_orders.exists?(freight_only: true)
  end

  private

  def link_origin_location
    self.origin_location = DispatchOrigin.resolve(origin)
  end

  def set_full_destination_address
    return unless destination_location.present?

    self.destination = "#{destination_location.address}, #{destination_location.city}, #{destination_location.state} #{destination_location.zip}"
  end

  def set_default_status
    self.dispatch_status = 'New'
  end
end
