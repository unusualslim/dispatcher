# Status flow for production orders: created → in_progress → quality_check → completed, plus
# admin-only voided. Completing needs the quality checks recorded and a quantity produced, then
# moves inventory; reopening reverses it; the GL journal follows the status (ProductionGlPosting).
module ProductionOrderWorkflow
  extend ActiveSupport::Concern

  included do
    # Set by controllers so inventory moves made on a status change record who made them.
    attr_accessor :acting_user

    before_save :stamp_date_completed, if: -> { will_save_change_to_status? && status == 'completed' }
    before_save :assign_lot_number, if: -> { will_save_change_to_status? && status == 'quality_check' }
    validate :ready_to_complete, on: :update, if: -> { will_save_change_to_status? && status == 'completed' }
    validate :voided_only_by_voiding, if: -> { will_save_change_to_status? && status == 'voided' }
    after_save :sync_inventory, if: :saved_change_to_status?
    after_update_commit -> { ProductionGlPosting.status_changed(self) }, if: :saved_change_to_status?
  end

  def voided?
    voided_at.present?
  end

  # Voided orders are kept for history and can't be changed.
  def readonly?
    (persisted? && voided_at_in_database.present?) || super
  end

  # The product's quality checks this order hasn't recorded yet.
  def missing_quality_checks
    return [] unless product

    recorded = quality_results.map(&:quality_spec_id)
    product.quality_specs.reject { |spec| recorded.include?(spec.id) }
  end

  private

  def ready_to_complete
    errors.add(:status, 'moves to Completed from Quality Check') unless status_in_database == 'quality_check'
    unless total_qty_produced.to_d.positive?
      errors.add(:total_qty_produced, 'is needed to complete (it goes into inventory)')
    end
    missing = missing_quality_checks
    errors.add(:base, "Record these quality checks first: #{missing.map(&:name).to_sentence}") if missing.any?
  end

  def voided_only_by_voiding
    errors.add(:status, 'is set to Voided only by voiding the order') if voided_at.blank?
  end

  def sync_inventory
    if status == 'completed'
      ProductionOrderInventory.post!(self, acting_user)
    elsif status_before_last_save == 'completed'
      ProductionOrderInventory.reverse!(self, acting_user)
    end
  end

  def assign_lot_number
    return if lot_number.present?

    prefix = "FPS-#{lot_code}-#{Time.zone.today.strftime('%Y%m%d')}-"
    sequence = self.class.where('lot_number LIKE ?', "#{prefix}%").count + 1
    self.lot_number = "#{prefix}#{sequence.to_s.rjust(3, '0')}"
  end

  def lot_code
    product&.name.to_s.gsub(/\W+/, '').upcase.first(6).presence || 'PROD'
  end

  def stamp_date_completed
    self.date_completed ||= Time.zone.today
  end
end
