class ReportingGroup < ApplicationRecord
  ACCOUNT_FORMAT = /\A[A-Za-z0-9]{1,10}-[A-Za-z0-9]{1,10}\z/ # Major-Sub; the site is prefixed per location

  # Same item types as PDI. Fuel and warehouse groups are PDI product categories; non-inventory
  # groups hold the BOM cost lines absorbed into production.
  ITEM_TYPES = {
    'fuel' => 'Fuel',
    'warehouse' => 'Warehouse',
    'non_inventory' => 'Non-inventory'
  }.freeze

  has_many :product_cost_lines, dependent: :restrict_with_error
  has_many :products, foreign_key: :category, primary_key: :name, inverse_of: :reporting_group,
                      dependent: :restrict_with_error

  normalizes :gl_account, :temp_gl_account, with: ->(account) { account.strip.presence }

  validates :name, presence: true, uniqueness: true
  validates :item_type, inclusion: { in: ITEM_TYPES.keys }
  validates :gl_account, :temp_gl_account, format: { with: ACCOUNT_FORMAT }, allow_nil: true
  validate :labor_only_for_non_inventory
  validate :production_gl_only_for_pdi_categories
  validate :pdi_name_unchanged, on: :update

  scope :ordered, -> { order(:position, :name) }
  scope :non_inventory, -> { where(item_type: 'non_inventory') }

  # Called when a product is saved with a category PDI hasn't sent before.
  def self.ensure_for_category!(name)
    find_or_create_by!(name: name) { |g| g.item_type = 'warehouse' }
  end

  def non_inventory?
    item_type == 'non_inventory'
  end

  # Fuel and warehouse group names come from PDI and link products by category.
  def pdi_category?
    !non_inventory?
  end

  def item_type_label
    ITEM_TYPES[item_type]
  end

  # Major-Sub to credit for actual labor by a worker of the given employment type.
  def account_for_employment(type)
    type == 'temp' ? temp_gl_account : gl_account
  end

  private

  def labor_only_for_non_inventory
    errors.add(:labor, 'applies only to non-inventory groups') if labor? && !non_inventory?
  end

  def production_gl_only_for_pdi_categories
    return unless post_production_gl? && non_inventory?

    errors.add(:post_production_gl, 'applies only to fuel and warehouse groups')
  end

  # PDI groups can switch between fuel and warehouse, but not to or from non-inventory.
  def pdi_name_unchanged
    errors.add(:name, 'comes from PDI and links products, so it cannot be renamed') if name_changed? && pdi_category?
    return unless item_type_changed? && [item_type_was, item_type].include?('non_inventory')

    errors.add(:item_type, 'cannot change between PDI categories and non-inventory')
  end
end
