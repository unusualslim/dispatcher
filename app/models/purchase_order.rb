class PurchaseOrder < ApplicationRecord
  STATUSES      = %w[draft pending_approval approved submitted received cancelled].freeze
  TRIGGER_TYPES = %w[auto_reorder mrp_shortage manual pdi_import].freeze

  belongs_to :vendor
  belongs_to :approved_by, class_name: 'User', optional: true
  belongs_to :received_by, class_name: 'User', optional: true

  has_many :line_items, class_name: 'PurchaseOrderLineItem', dependent: :destroy
  accepts_nested_attributes_for :line_items, allow_destroy: true, reject_if: :all_blank

  validates :status,       inclusion: { in: STATUSES }
  validates :trigger_type, inclusion: { in: TRIGGER_TYPES }, allow_nil: true
  validates :pdi_reference, uniqueness: true, allow_nil: true

  after_update_commit :enqueue_pdi_export, if: :submitted?

  def submitted?
    status == 'submitted' && saved_change_to_status?
  end

  scope :pending_approval, -> { where(status: 'pending_approval') }
  scope :draft,            -> { where(status: 'draft') }
  scope :active,           -> { where(status: %w[draft pending_approval approved submitted]) }

  def total_cost
    line_items.sum { |li| li.total_cost || 0 }
  end

  def posted?
    posted_at.present?
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
    transaction do
      line_items.includes(:product).each do |line|
        next unless line.product.present? && line.quantity.to_d > 0
        InventoryTransaction.create!(
          product:          line.product,
          quantity:         line.quantity,
          direction:        'in',
          transactable:     self,
          reference_number: pdi_reference || id.to_s,
          notes:            "PO received from #{vendor.name}",
          created_by_id:    user.id
        )
        line.product.increment!(:current_stock, line.quantity)
      end
      update!(posted_at: Time.current)
    end
    true
  end

  private

  def enqueue_pdi_export
    PdiExportJob.perform_later(id)
  end
end
