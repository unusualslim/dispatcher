# Merges one customer (source: usually an app customer the PDI Master Data import couldn't match by name)
# into another (target: usually the PDI-linked one the import created). The source's orders, quotes,
# pricing rules, production orders, phone numbers and delivery locations move to the target, its blank
# email/phone fill the target's, and the source is deleted. Duplicate ship-to locations are folded
# together by CustomerMerge::LocationPairs.
class CustomerMerge
  # Records that move by customer_id, as they're labelled on the preview.
  MOVES = { 'Orders' => CustomerOrder, 'Quotes' => Quote, 'Pricing rules' => PricingRule,
            'Production orders' => ProductionOrder }.freeze

  attr_reader :source, :target

  def initialize(source, target)
    raise ArgumentError, "Can't merge a customer into itself" if source == target
    if source.pdi_customer_id.present?
      raise ArgumentError, "#{source.name} is linked to PDI (#{source.pdi_customer_id}); merge the other way"
    end

    @source = source
    @target = target
  end

  def counts
    MOVES.transform_values { |model| model.where(customer_id: source.id).count }
         .merge('Phone numbers' => source.phone_numbers.count, 'Locations' => source.customer_locations.count)
  end

  def locations
    @locations ||= LocationPairs.new(source, target)
  end

  # Target's blank contact fields that the source fills.
  def contact_fills
    { email: source.email, phone: source.phone }.select { |field, value| value.present? && target[field].blank? }
  end

  # "12 orders, 2 quotes, 3 locations"
  def summary
    counts.reject { |_, n| n.zero? }.map { |label, n| "#{n} #{label.downcase}" }.join(', ')
  end

  def merge!
    Customer.transaction do
      move_records
      move_phone_numbers
      locations.apply!
      target.update!(contact_fills) if contact_fills.any?
      source.reload.destroy!
    end
  end

  private

  def move_records
    MOVES.each_value do |model|
      model.where(customer_id: source.id).update_all(customer_id: target.id) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  # Empty numbers and ones the target already has (compared by digits) are dropped, not moved.
  def move_phone_numbers
    existing = target_numbers
    source.phone_numbers.each do |phone|
      number = digits(phone.number)
      number.present? && existing.exclude?(number) ? phone.update!(customer: target) : phone.destroy!
      existing << number
    end
  end

  def target_numbers
    (target.phone_numbers.pluck(:number) + [target.phone]).map { |number| digits(number) }
  end

  def digits(number)
    number.to_s.gsub(/\D/, '')
  end
end
