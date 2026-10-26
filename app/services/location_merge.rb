# Merges one location (source) into another (target) and deletes the source: everything that points at
# it moves (orders, dispatches, quotes, production/purchase orders, inventory, contacts, work orders,
# customer links), stock and tank settings combine, notes are appended, and the target's blank fields
# fill from the source. For duplicates of the same place, e.g. "TA Travel Center" vs PDI ship-to 177.
class LocationMerge
  MOVES = { 'Orders' => [CustomerOrder, :location_id], 'Dispatches' => [Dispatch, :destination_location_id],
            'Quotes' => [Quote, :location_id], 'Production orders' => [ProductionOrder, :location_id],
            'Purchase orders' => [PurchaseOrder, :location_id],
            'Inventory movements' => [InventoryTransaction, :location_id],
            'Contacts' => [LocationContact, :location_id],
            'Order lines (warehouse)' => [CustomerOrderProduct, :location_id] }.freeze

  FILLS = %w[address city state zip phone_number latitude longitude max_capacity uleage_90 cutoff_percent
             marker_color pdi_site_code pdi_terminal_id].freeze
  TANK_SETTINGS = %w[max_capacity uleage_90 cutoff].freeze

  attr_reader :source, :target

  def initialize(source, target)
    @source = source
    @target = target
    problem = refusal
    raise ArgumentError, problem if problem
  end

  def counts
    MOVES.transform_values { |(model, column)| model.where(column => source.id).count }
         .merge('Work orders' => source.work_orders.count, 'Stock / tank rows' => source.location_products.count,
                'Customer links' => source.customer_locations.count)
  end

  # Target's blank fields that the source fills.
  def fills
    FILLS.index_with { |field| source[field] }.select { |field, value| value.present? && target[field].blank? }
  end

  # "3 orders, 1 customer links"
  def summary
    counts.reject { |_, n| n.zero? }.map { |label, n| "#{n} #{label.downcase}" }.join(', ')
  end

  def merge!
    Location.transaction do
      move_records
      Links.new(source, target).apply!
      move_stock
      merge_notes
      fill_target
      source.reload.destroy!
    end
  end

  private

  def refusal
    return "Can't merge a location into itself" if source == target
    return 'Only locations of the same type can be merged' if source.location_category_id != target.location_category_id

    clash = Links.new(source, target).ship_to_clash
    clash_message(clash) if clash
  end

  def clash_message(clash)
    other = target.customer_locations.find_by(customer_id: clash.customer_id).pdi_location_id
    "#{clash.customer.name} has both as separate PDI ship-tos (#{clash.pdi_location_id} and #{other})"
  end

  def move_records
    MOVES.each_value do |(model, column)|
      model.where(column => source.id).update_all(column => target.id) # rubocop:disable Rails/SkipsModelValidations
    end
    source.work_orders.update_all(workable_id: target.id) # rubocop:disable Rails/SkipsModelValidations
  end

  # One stock / tank row per product: quantities add up, the target's settings win where set.
  def move_stock
    source.location_products.each do |row|
      existing = target.location_products.find_by(product_id: row.product_id)
      existing ? combine(existing, row) : row.update!(location: target)
    end
    move_legacy_products
  end

  def combine(existing, row)
    settings = TANK_SETTINGS.select { |f| existing[f].blank? }.index_with { |f| row[f] }
    existing.update!(settings.merge('quantity' => existing.quantity + row.quantity))
    row.destroy!
  end

  # The old locations_products join table has no model.
  def move_legacy_products
    connection = ActiveRecord::Base.connection
    connection.execute(<<~SQL.squish)
      INSERT INTO locations_products (location_id, product_id)
      SELECT #{target.id.to_i}, product_id FROM locations_products s WHERE s.location_id = #{source.id.to_i}
        AND NOT EXISTS (SELECT 1 FROM locations_products t WHERE t.location_id = #{target.id.to_i}
                        AND t.product_id = s.product_id)
    SQL
    connection.execute("DELETE FROM locations_products WHERE location_id = #{source.id.to_i}")
  end

  def merge_notes
    target.notes = [target.notes, source.notes].compact_blank.join("\n\n") if source.notes.present?
    %i[location_notes dispatch_notes].each { |name| merge_rich_text(name) }
  end

  def merge_rich_text(name)
    extra = source.public_send(name)&.body
    return if extra.blank?

    current = target.public_send(name)&.body
    target.public_send(:"#{name}=", current.present? ? "#{current}<hr>#{extra}" : extra.to_s)
  end

  # The source's unique PDI terminal ID has to leave it before the target can take it.
  def fill_target
    values = fills
    source.update_columns(pdi_terminal_id: nil) if values.key?('pdi_terminal_id') # rubocop:disable Rails/SkipsModelValidations
    target.assign_attributes(values)
    target.save!
  end
end
