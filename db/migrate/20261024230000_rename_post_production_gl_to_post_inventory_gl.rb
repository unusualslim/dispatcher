# The category switch means "the app posts this category's inventory side (inventory, COGS, sales)",
# not production costing, which always posts.
class RenamePostProductionGlToPostInventoryGl < ActiveRecord::Migration[7.2]
  def change
    rename_column :reporting_groups, :post_production_gl, :post_inventory_gl
  end
end
