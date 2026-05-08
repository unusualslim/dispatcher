class PurchaseOrder < ApplicationRecord
  STATUSES      = %w[draft pending_approval approved submitted received cancelled].freeze
  TRIGGER_TYPES = %w[auto_reorder mrp_shortage manual].freeze

  belongs_to :vendor
  belongs_to :product
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :received_by, class_name: 'User', optional: true

  validates :status,       inclusion: { in: STATUSES }
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }, allow_nil: true
  validates :quantity,     numericality: { greater_than: 0 }

  after_update_commit :enqueue_pdi_export, if: :submitted?

  def submitted?
    status == 'submitted' && saved_change_to_status?
  end

  scope :pending_approval, -> { where(status: 'pending_approval') }
  scope :draft,            -> { where(status: 'draft') }
  scope :active,           -> { where(status: %w[draft pending_approval approved submitted]) }

  private

  def enqueue_pdi_export
    PdiExportJob.perform_later(id)
  end

  public

  def total_cost
    return nil if quantity.nil? || unit_cost.nil?
    quantity * unit_cost
  end

  def approve!(user)
    update!(
      status: 'approved',
      approved_by: user,
      expected_delivery_date: vendor.lead_time_days ? Date.today + vendor.lead_time_days : nil
    )
  end

  def mark_received!(user, received_at: Time.current)
    transaction do
      update!(status: 'received', received_at: received_at, received_by: user)
      InventoryTransaction.create!(
        product:          product,
        quantity:         quantity,
        direction:        'in',
        transactable:     self,
        reference_number: id.to_s,
        notes:            "PO received from #{vendor.name}",
        created_by_id:    user.id
      )
      product.increment!(:current_stock, quantity)
    end
  end
end
