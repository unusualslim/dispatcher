class ValidateProductionOrdersBomVersionFk < ActiveRecord::Migration[8.1]
  def change
    validate_foreign_key :production_orders, :bom_versions
  end
end
