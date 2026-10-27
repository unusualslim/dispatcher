class PurchaseOrder < ApplicationRecord
  # voided: cancelled by an admin (PurchaseOrderVoid), posted receipts reversed, kept read-only
  STATUSES      = %w[draft pending_approval approved submitted received cancelled voided].freeze
  TRIGGER_TYPES = %w[auto_reorder mrp_shortage manual pdi_import].freeze

  belongs_to :vendor
  belongs_to :location, optional: true
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :received_by, class_name: 'User', optional: true
  belongs_to :voided_by, class_name: 'User', optional: true

  has_many :line_items, class_name: 'PurchaseOrderLineItem', dependent: :destroy
  has_many :inventory_transactions, as: :transactable
  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: :all_blank

  validates :status,       inclusion: { in: STATUSES }
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }, allow_nil: true
  validates :pdi_reference, uniqueness: true, allow_nil: true
  validate :freight_term_allowed_for_vendor

  def freight_term_allowed_for_vendor
    return if freight_terms.blank? || vendor_id.blank?

    allowed = vendor&.freight_term_names || []
    return if allowed.empty?

    errors.add(:freight_terms, 'is not an allowed freight term for this vendor') unless allowed.include?(freight_terms)
  end

  # POs that came from PDI are already there; only app-entered POs are sent.
  after_update_commit :enqueue_pdi_export, if: :submitted?, unless: :from_pdi?

  def submitted?
    status == 'submitted' && saved_change_to_status?
  end

  def from_pdi?
    trigger_type == 'pdi_import'
  end

  # Stock goes to a warehouse; dropship POs (no warehouse) never enter inventory.
  def postable?
    status == 'received' && !posted? && location.present?
  end

  scope :pending_approval, -> { where(status: 'pending_approval') }
  scope :draft,            -> { where(status: 'draft') }
  scope :active,           -> { where(status: %w[draft pending_approval approved submitted]) }

  def display_number
    pdi_reference.presence || "##{id}"
  end

  def subtotal
    line_items.sum { |li| li.total_cost || 0 }
  end

  def total_cost
    subtotal +
      (respond_to?(:freight_amount) ? freight_amount.to_f : 0) +
      (respond_to?(:other_charges)  ? other_charges.to_f  : 0)
  end

  def posted?
    posted_at.present?
  end

  def voided?
    voided_at.present?
  end

  # Voided POs are kept for history and can't be changed.
  def readonly?
    (persisted? && voided_at_in_database.present?) || super
  end

  def approve!(user)
    update!(
      status: 'approved',
      approved_by: user,
      expected_delivery_date: vendor.lead_time_days ? Date.today + vendor.lead_time_days : nil
    )
  end

  def mark_received!(user, received_at: Time.current)
    update!(status: 'received', received_at: received_at, received_by: user)
  end

  def post_to_inventory!(user)
    return false if posted?
    raise ArgumentError, 'This PO has no warehouse (dropship), so it does not go into inventory' unless location

    transaction do
      line_items.includes(:product).each { |line| post_line!(line, user) }
      # update_columns: PDI history can fail validations.
      update_columns(posted_at: Time.current, updated_at: Time.current)
    end
    true
  end

  private

  # A receipt at the line's cost, dated when the PO was received.
  def post_line!(line, user)
    return unless line.product.present? && line.quantity.to_d.positive?

    InventoryPosting.post!(
      product: line.product, location: location, quantity: line.quantity, movement_type: 'receipt',
      unit_cost: line.unit_cost, source: self, reference: pdi_reference || id.to_s,
      notes: "PO received from #{vendor.name}", user: user, occurred_on: received_at&.to_date
    )
  end

  def enqueue_pdi_export
    PdiExportJob.perform_later(id)
  end
end
