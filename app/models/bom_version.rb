# A saved version of a product's bill of materials: its components (item, quantity per unit, UOM) and cost lines as
# they stood from effective_on. A new version is saved whenever the BOM is changed (product page, BOM import) or when
# a production order is created and the BOM differs from the last saved version; each production order keeps the
# version it was made with.
class BomVersion < ApplicationRecord
  belongs_to :product
  belongs_to :created_by, class_name: 'User', optional: true
  has_many :production_orders, dependent: :nullify

  scope :newest_first, -> { order(number: :desc) }

  # Saves a new version when the product's BOM differs from its latest one; returns the current version (nil when
  # the product has no BOM and never had one).
  def self.capture!(product, user: nil, source: nil)
    snapshot = snapshot_of(product)
    latest = product.bom_versions.newest_first.first
    return latest if latest && latest.content == snapshot
    return if latest.nil? && snapshot.values.all?(&:empty?)

    product.bom_versions.create!(number: latest&.number.to_i + 1, effective_on: Date.current, created_by: user,
                                 source: source, **snapshot)
  end

  def self.snapshot_of(product)
    product = Product.includes(:product_components, :product_cost_lines).find(product.id)
    { components: product.product_components.sort_by { |c| [c.component_product_id.to_s, c.id] }
                         .map { |c| component_row(c) },
      cost_lines: product.product_cost_lines.map { |l| cost_line_row(l) } }
  end

  def self.component_row(component)
    { 'component_product_id' => component.component_product_id,
      'quantity_per_unit' => number(component.quantity_per_unit), 'uom' => component.uom }
  end

  def self.cost_line_row(line)
    { 'description' => line.description, 'cost_item_id' => line.cost_item_id,
      'reporting_group_id' => line.reporting_group_id, 'quantity' => number(line.quantity),
      'per_quantity' => number(line.per_quantity) }
  end

  # "2.5" for 2.5000, "2" for 2.0 (nil stays nil).
  def self.number(value)
    value.to_d.to_s('F').sub(/\.0\z/, '') unless value.nil?
  end

  def content
    { components: components, cost_lines: cost_lines }
  end

  # What changed from the version before: ["Added 901 (0.5 GA)", "Removed 777", "Changed 101: 2 LB → 3 LB"].
  def changes_from(previous)
    return ['First saved version'] unless previous

    before = previous.components.index_by { |c| c['component_product_id'] }
    after = components.index_by { |c| c['component_product_id'] }
    changes = component_changes(before, after)
    changes << 'Cost lines changed' if cost_lines != previous.cost_lines
    changes.presence || ['No change']
  end

  private

  def component_changes(before, after)
    added = (after.keys - before.keys).map { |id| "Added #{id} (#{qty(after[id])})" }
    removed = (before.keys - after.keys).map { |id| "Removed #{id}" }
    added + removed + changed(before, after)
  end

  def changed(before, after)
    (after.keys & before.keys).reject { |id| before[id] == after[id] }
                              .map { |id| "Changed #{id}: #{qty(before[id])} → #{qty(after[id])}" }
  end

  def qty(component)
    [component['quantity_per_unit'], component['uom']].compact_blank.join(' ')
  end
end
