class ProductionOrderBatch < ApplicationRecord
  QC_STATUSES = %w[pending passed hold rejected].freeze

  belongs_to :production_order
  validates :batch_number, presence: true
  validates :quantity, numericality: { greater_than: 0 }
  validates :qc_status, inclusion: { in: QC_STATUSES }

  def passed?
    qc_status == 'passed'
  end

  def generate_lot_number!(product_code = nil)
    code = product_code || production_order&.product&.name&.gsub(/\s+/, '')&.upcase&.first(6) || 'PROD'
    date = Time.current.strftime('%Y%m%d')
    sequence = self.class.where('lot_number LIKE ?', "FPS-#{code}-#{date}-%").count + 1
    self.lot_number = "FPS-#{code}-#{date}-#{sequence.to_s.rjust(3, '0')}"
    save!
  end

  def complete_and_deduct_inventory!(completed_by_user)
    return false unless passed?
    return false unless production_order.present?

    ActiveRecord::Base.transaction do
      # Deduct raw materials consumed
      production_order.production_order_components.includes(:product).each do |comp|
        next unless comp.product&.is_raw_material?
        actual_qty = comp.quantity_actual || comp.quantity
        next unless actual_qty&.positive?

        InventoryTransaction.create!(
          product:          comp.product,
          quantity:         actual_qty,
          direction:        'out',
          transactable:     self,
          reference_number: production_order.number,
          notes:            "Consumed in batch #{lot_number}",
          created_by_id:    completed_by_user.id
        )
        comp.product.decrement!(:current_stock, actual_qty)
      end

      # Add finished goods to inventory
      finished_product = production_order.product
      if finished_product && !finished_product.is_raw_material?
        qty_produced = quantity || production_order.qty_to_make
        InventoryTransaction.create!(
          product:          finished_product,
          quantity:         qty_produced,
          direction:        'in',
          transactable:     self,
          reference_number: production_order.number,
          notes:            "Produced in batch #{lot_number}",
          created_by_id:    completed_by_user.id
        )
        finished_product.increment!(:current_stock, qty_produced)
      end

      # Trigger reorder check for any materials that dropped below reorder point
      ReorderCheckJob.perform_later
    end
    true
  end
end
