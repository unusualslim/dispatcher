class BomImportsController < ApplicationController
  before_action :require_admin!

  def new
    @existing_count = ProductComponent.count
    @product_count  = Product.joins(:product_components).distinct.count
  end

  def create
    file = params[:file]
    return redirect_to new_bom_import_path, alert: "Please select a file." unless file

    unless file.original_filename.downcase.end_with?('.csv')
      return redirect_to new_bom_import_path, alert: "File must be a CSV file."
    end

    result = BomImportService.call(file.path)

    summary = "Import complete — #{result.created} components created across products. " \
              "#{result.skipped_no_product} products not found in LoadNTrucks, " \
              "#{result.skipped_already_has_bom} products already had a BOM (skipped)."
    summary += " #{result.errors.count} warnings (see below)." if result.errors.any?

    flash[:notice]   = summary
    flash[:warnings] = result.errors if result.errors.any?
    redirect_to new_bom_import_path
  end
end
