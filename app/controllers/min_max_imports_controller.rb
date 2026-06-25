class MinMaxImportsController < ApplicationController
  before_action :require_admin!

  def new
    @products_with_minmax = Product.where.not(reorder_point: nil).or(Product.where.not(max_stock: nil)).count
  end

  def create
    file = params[:file]
    return redirect_to new_min_max_import_path, alert: "Please select a file." unless file

    unless file.original_filename.downcase.end_with?('.xlsx')
      return redirect_to new_min_max_import_path, alert: "File must be an XLSX file."
    end

    result = MinMaxImportService.call(file.path)

    summary = "Import complete — #{result.updated} products updated with min/max values. " \
              "#{result.skipped_no_product} part numbers not found in LoadNTrucks, " \
              "#{result.skipped_no_values} rows skipped (no min or max set)."
    summary += " #{result.errors.count} errors." if result.errors.any?

    flash[:notice]   = summary
    flash[:warnings] = result.errors if result.errors.any?
    redirect_to new_min_max_import_path
  end
end
