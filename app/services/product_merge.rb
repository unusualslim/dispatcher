# Merges an obsolete product (source) into the product that replaced it (target), e.g. the app-only FPS001 "DEF
# (bulk)" into PDI's 901. Its history follows: order, quote, PO and production lines, inventory movements and cost
# history, tanks, stock / tank rows, BOM uses, pricing rule and vendor links. Its own definitions (BOM, cost lines,
# quality specs) move only when the target has none; otherwise they stay on the source. The source is then left
# inactive (not deleted), so quality results and anything else still pointing at it keep working.
# Refused while the source still holds stock: adjust it out (or move it) first.
class ProductMerge # rubocop:disable Metrics/ClassLength
  MOVES = {
    'Order lines' => [CustomerOrderProduct, :product_id], 'Quote lines' => [QuoteProduct, :product_id],
    'Purchase order lines' => [PurchaseOrderLineItem, :product_id],
    'Production orders' => [ProductionOrder, :product_id],
    'Production order components' => [ProductionOrderComponent, :product_id],
    'Inventory movements' => [InventoryTransaction, :product_id], 'Cost layers' => [InventoryCostLayer, :product_id],
    'Standard cost history' => [StandardCostHistory, :product_id],
    'Cost history' => [InventoryCostHistory, :product_id],
    'Used as a BOM component' => [ProductComponent, :component_product_id], 'Tanks' => [Tank, :product_id]
  }.freeze
  # A product's own recipe and checks: moved only when the target has none of its own.
  DEFINITIONS = { 'BOM lines' => ProductComponent, 'Cost lines' => ProductCostLine,
                  'Quality specs' => QualitySpec }.freeze
  # One row per product and key: the source's row moves unless the target already has one for that key.
  LINKS = { 'Pricing rule links' => [PricingRuleProduct, :pricing_rule_id],
            'Vendor links' => [ProductVendor, :vendor_id] }.freeze
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
         .merge(link_counts, 'Stock / tank rows' => source.location_products.count)
         .merge(definition_counts.select { |label, _| moves_definition?(label) })
  end

  # Definitions the source keeps because the target has its own: { 'BOM lines' => 3 }
  def kept_on_source
    definition_counts.select { |label, n| n.positive? && !moves_definition?(label) }
  end

  def summary
    counts.reject { |_, n| n.zero? }.map { |label, n| "#{n} #{label.downcase}" }.join(', ')
  end

  def merge!
    Product.transaction do
      plan = DEFINITIONS.keys.index_with { |label| moves_definition?(label) } # decided before anything moves
      move_records
      move_definitions(plan)
      move_links
      move_stock_rows
      move_legacy_products
      source.update_columns(active: false, updated_at: Time.current) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  private

  def link_counts
    LINKS.transform_values { |(model, _)| model.where(product_id: source.id).count }
  end

  def definition_counts
    @definition_counts ||= DEFINITIONS.transform_values { |model| model.where(product_id: source.id).count }
  end

  def refusal
    return "Can't merge a product into itself" if source == target
    return "#{source.id} still has stock on hand; adjust it out before merging" if holds_stock?

    nil
  end

  def holds_stock?
    source.current_stock.to_d.nonzero? || stock_rows? ||
      InventoryCostLayer.where(product_id: source.id).where.not(remaining_quantity: 0).exists?
  end

  def stock_rows?
    rows = source.location_products
    rows.where.not(quantity: 0).or(rows.where.not(inventory_value: 0)).exists?
  end

  def moves_definition?(label)
    !DEFINITIONS[label].exists?(product_id: target.id)
  end

  def move_records
    MOVES.each_value do |(model, column)|
      model.where(column => source.id).update_all(column => target.id) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  def move_definitions(plan)
    plan.each do |label, moves|
      DEFINITIONS[label].where(product_id: source.id).update_all(product_id: target.id) if moves # rubocop:disable Rails/SkipsModelValidations
    end
  end

  # The target's own link wins; the source's duplicate is dropped.
  def move_links
    LINKS.each_value do |(model, key)|
      taken = model.where(product_id: target.id).pluck(key)
      model.where(product_id: source.id, key => taken).delete_all
      model.where(product_id: source.id).update_all(product_id: target.id) # rubocop:disable Rails/SkipsModelValidations
    end
  end

  # One stock / tank row per location: the target's settings win where set (no quantities: refused above).
  def move_stock_rows
    source.location_products.each do |row|
      existing = target.location_products.find_by(location_id: row.location_id)
      existing ? combine(existing, row) : row.update!(product_id: target.id)
    end
  end

  def combine(existing, row)
    settings = TANK_SETTINGS.select { |field| existing[field].blank? }.index_with { |field| row[field] }
    existing.update!(settings.compact)
    row.destroy!
  end

  # The old locations_products join table has no model.
  def move_legacy_products
    connection = ActiveRecord::Base.connection
    src = connection.quote(source.id)
    tgt = connection.quote(target.id)
    connection.execute(<<~SQL.squish)
      INSERT INTO locations_products (location_id, product_id)
      SELECT location_id, #{tgt} FROM locations_products s WHERE s.product_id = #{src}
        AND NOT EXISTS (SELECT 1 FROM locations_products t WHERE t.product_id = #{tgt} AND t.location_id = s.location_id)
    SQL
    connection.execute("DELETE FROM locations_products WHERE product_id = #{src}")
  end
end
