# Posts production orders' FPST journals automatically: when an order is completed (if its journal
# is ready) and from the scheduled PDI GL Export, which also catches orders that became ready later.
# Reopening a completed order reverses its entry. Only orders completed on or after the
# "GL posting start date" setting are posted automatically; a blank date turns it off.
module ProductionGlPosting
  module_function

  def start_date
    Date.parse(AppSetting.get('gl_posting_start_date').to_s)
  rescue Date::Error
    nil
  end

  def status_changed(order)
    if order.status == 'completed'
      auto_post(order)
    elsif (entry = LedgerEntry.active_for(order))
      entry.reverse!(nil)
    end
  rescue StandardError => e
    Rails.logger.error "[ProductionGlPosting] #{order.number}: #{e.message}"
  end

  # Returns the posted entry, or nil when the order isn't eligible or its journal isn't ready.
  def auto_post(order)
    return unless eligible?(order) && LedgerEntry.active_for(order).nil?

    journal = ProductionOrderJournal.new(order)
    LedgerEntry.post!(journal, nil) if journal.ready?
  end

  def eligible?(order)
    start = start_date
    start.present? && order.status == 'completed' && order.date_completed.present? && order.date_completed >= start
  end

  # Posts every eligible completed order that has no entry in force yet; returns how many posted.
  def post_ready_orders!
    start = start_date
    return 0 unless start

    ProductionOrder.where(status: 'completed').where(date_completed: start..).find_each.count do |order|
      auto_post(order)
    rescue StandardError => e
      Rails.logger.error "[ProductionGlPosting] #{order.number}: #{e.message}"
      false
    end
  end
end
