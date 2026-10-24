class AddPostProductionGlToReportingGroups < ActiveRecord::Migration[7.2]
  def change
    # Fuel/warehouse categories whose production orders get the app's FPST journal; off leaves it all to PDI.
    add_column :reporting_groups, :post_production_gl, :boolean, null: false, default: false
  end
end
