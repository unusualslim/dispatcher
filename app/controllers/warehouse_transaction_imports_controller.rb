class WarehouseTransactionImportsController < ApplicationController
  before_action :require_admin!

  def new
    @existing_count = InventoryTransaction.where("notes LIKE ?", "[PDI Historical Import]%").count
  end

  def create
    file = params[:file]
    return redirect_to new_warehouse_transaction_import_path, alert: "Please select a file." unless file

    unless file.original_filename.downcase.end_with?('.xls', '.xlsx')
      return redirect_to new_warehouse_transaction_import_path, alert: "File must be an XLS or XLSX file."
    end

    result = WarehouseTransactionImportService.call(file.path)

    summary = "Import complete — #{result.imported} imported, " \
              "#{result.skipped_no_product} skipped (product not found), " \
              "#{result.skipped_duplicate} duplicates skipped."
    summary += " #{result.errors.count} rows had errors." if result.errors.any?

    redirect_to new_warehouse_transaction_import_path, notice: summary
  end
end
