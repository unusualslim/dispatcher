# Accounting → Standard Cost Exceptions: the standard-cost problems someone should look at, so the team can work
# by exception (like Quality Exceptions). Standard-costed items = items in a reporting group on standard costing,
# plus anything a BOM makes or uses (everything manufacturing touches is on standard).
#
#   receipt_ppv          a PO receipt whose actual cost is off standard by more than the tolerance (last 90 days)
#   production_variance  a completed production order whose material + labor variance, or yield, is off by more
#                        than the tolerance (last 90 days)
#   cost_drift           the standard no longer matches what the item costs now: bought items against their last
#                        receipt, made items against their BOM cost
#   missing_standard     a standard-costed item with no standard cost
#
# Variances smaller than the minimum amount are left out. A review (ExceptionReview) takes an item off the list;
# drift reviews hold only while the standard and current cost stay as reviewed.
class StandardCostExceptions # rubocop:disable Metrics/ClassLength -- four exception kinds, each a few small steps
  KINDS = {
    'receipt_ppv' => 'Receipt price variance',
    'production_variance' => 'Production variance',
    'cost_drift' => 'Standard out of date',
    'missing_standard' => 'No standard cost'
  }.freeze
  SETTINGS = { 'std_exception_pct' => 5, 'std_drift_pct' => 10, 'std_exception_min_amount' => 25 }.freeze
  LOOKBACK_DAYS = 90

  Item = Struct.new(:kind, :subject_key, :fingerprint, :title, :detail, :amount, :pct, :date, :path, :review,
                    keyword_init: true) do
    def kind_label = KINDS[kind]
    def reviewed? = review.present?
    def sort_key = [-(date || Date.new(1900)).jd, -amount.to_d.abs]
  end

  def self.setting(key) = (AppSetting.get(key).presence || SETTINGS.fetch(key)).to_d

  def initialize(today: Date.current)
    @today = today
  end

  def items
    @items ||= (receipt_items + production_items + drift_items + missing_items).each { |item| attach_review(item) }
                                                                               .sort_by(&:sort_key)
  end

  private

  def attach_review(item)
    @reviews ||= KINDS.keys.index_with { |kind| ExceptionReview.lookup(kind) }
    item.review = @reviews[item.kind][[item.subject_key, item.fingerprint]]
  end

  def routes = Rails.application.routes.url_helpers
  def since = @today - LOOKBACK_DAYS
  def tolerance = self.class.setting('std_exception_pct') / 100
  def min_amount = self.class.setting('std_exception_min_amount')
  def over?(pct, amount) = pct && pct.abs > tolerance && amount.abs >= min_amount

  # Receipts --------------------------------------------------------------------------------------------------

  def receipt_items
    recent_receipts.select { |txn| over?(receipt_pct(txn), txn.variance_amount) }.map { |txn| receipt_item(txn) }
  end

  # Receipts with a variance in the lookback window, leaving out any that were reversed (voided POs).
  def recent_receipts
    reversed = InventoryTransaction.where.not(reversal_of_id: nil).select(:reversal_of_id)
    InventoryTransaction.where(movement_type: 'receipt', occurred_on: since.., reversal_of_id: nil)
                        .where.not(id: reversed).where.not(variance_amount: [nil, 0]).where.not(total_cost: [nil, 0])
                        .includes(:product)
  end

  def receipt_pct(txn) = txn.variance_amount.to_d / txn.total_cost.to_d.abs

  def receipt_item(txn)
    Item.new(kind: 'receipt_ppv', subject_key: "txn:#{txn.id}", fingerprint: '', amount: txn.variance_amount,
             pct: receipt_pct(txn), date: txn.occurred_on, title: product_title(txn.product, txn.product_id),
             detail: receipt_detail(txn), path: receipt_path(txn))
  end

  def receipt_detail(txn)
    qty = txn.quantity.to_d.nonzero? || 1
    actual = (txn.total_cost.to_d + txn.variance_amount.to_d) / qty
    "#{txn.reference_number.presence || 'Receipt'}: #{fmt_qty(qty)} at #{money(actual)} vs standard " \
      "#{money(txn.unit_cost)}"
  end

  def receipt_path(txn)
    routes.purchase_order_path(txn.transactable_id) if txn.transactable_type == 'PurchaseOrder'
  end

  # Production ------------------------------------------------------------------------------------------------

  def production_items
    Reports::ProductionVariance.new({ from: since.iso8601, to: @today.iso8601 }).rows
                               .select { |row| production_exception?(row) }.map { |row| production_item(row) }
  end

  def production_variance(row) = row[:material_variance].to_d + row[:labor_variance].to_d

  def production_pct(row)
    base = row[:material_standard].to_d
    production_variance(row) / base if base.positive?
  end

  def production_exception?(row)
    over?(production_pct(row), production_variance(row)) || (row[:yield] && (1 - row[:yield]).abs > tolerance)
  end

  def production_item(row)
    Item.new(kind: 'production_variance', subject_key: "po:#{row[:order_id]}", fingerprint: '',
             amount: production_variance(row), pct: production_pct(row), date: row[:completed],
             title: "#{row[:order]} · #{row[:product]}", detail: production_detail(row),
             path: routes.production_order_path(row[:order_id]))
  end

  def production_detail(row)
    parts = ["Material #{money(row[:material_variance])}", "labor #{money(row[:labor_variance])}",
             "total #{money(production_variance(row))} (positive = under standard)"]
    parts << "yield #{(row[:yield] * 100).round(1)}%" if row[:yield]
    parts.join(' · ')
  end

  # Standards -------------------------------------------------------------------------------------------------

  def drift_items
    standard_products.select { |p| p.standard_cost.to_d.positive? }.filter_map { |product| drift_item(product) }
  end

  def drift_item(product)
    compare, source = current_cost(product)
    standard = product.standard_cost.to_d
    pct = compare && ((compare - standard) / standard)
    return unless compare&.positive? && pct.abs > drift

    Item.new(kind: 'cost_drift', subject_key: "product:#{product.id}", amount: compare - standard, pct: pct,
             fingerprint: "#{standard.round(4)}|#{compare.round(4)}", **product_ref(product),
             detail: drift_detail(standard, source, compare))
  end

  def drift_detail(standard, source, compare) = "Standard #{money(standard)} · #{source} #{money(compare)}"

  def product_ref(product) = { title: product_title(product, product.id), path: routes.product_path(product) }

  def drift = self.class.setting('std_drift_pct') / 100

  def missing_items
    standard_products.reject { |p| p.standard_cost.to_d.positive? }.map do |product|
      Item.new(kind: 'missing_standard', subject_key: "product:#{product.id}", fingerprint: '',
               title: product_title(product, product.id), path: routes.product_path(product),
               detail: bom_parents.include?(product.id) ? 'Made here (has a BOM)' : 'Standard-costed, no standard set')
    end
  end

  # Made items against their BOM standard; bought items against their last receipt's actual cost.
  def current_cost(product)
    if bom_parents.include?(product.id)
      [product.bom_standard_cost&.to_d, 'BOM cost']
    elsif last_receipts[product.id]
      [last_receipts[product.id], 'last receipt']
    end
  end

  def last_receipts
    @last_receipts ||= InventoryTransaction.where(movement_type: 'receipt', reversal_of_id: nil)
                                           .where.not(total_cost: nil).where('quantity > 0').order(:occurred_on, :id)
                                           .pluck(:product_id, :total_cost, :variance_amount, :quantity)
                                           .to_h { |id, total, var, qty| [id, (total.to_d + var.to_d) / qty.to_d] }
  end

  def standard_products
    @standard_products ||= begin
      grouped = Product.joins(:reporting_group).where(reporting_groups: { costing_method: 'standard' }).select(:id)
      Product.active.where(id: grouped).or(Product.active.where(id: bom_parents.to_a + bom_components.to_a))
             .order(:id).to_a
    end
  end

  def bom_parents = @bom_parents ||= ProductComponent.distinct.pluck(:product_id).to_set
  def bom_components = @bom_components ||= ProductComponent.distinct.pluck(:component_product_id).to_set

  def product_title(product, id) = [id, product&.name].compact.join(' · ')
  def money(value) = ActiveSupport::NumberHelper.number_to_currency(value, precision: value.to_d.abs < 10 ? 4 : 2)
  def fmt_qty(qty) = ActiveSupport::NumberHelper.number_to_delimited(qty.to_d.round(3).to_s('F').delete_suffix('.0'))
end
