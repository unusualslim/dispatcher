# frozen_string_literal: true

# Hub page listing every manual import, with each one's most recent run.
class ImportsController < ApplicationController
  before_action :require_admin!

  # path: route helper; process: SyncLog process_name (nil when the import doesn't log).
  IMPORTS = [
    { group: 'Regular', title: 'Customer Orders', icon: 'bi-file-earmark-arrow-up',
      path: :new_customer_order_import_path,
      process: CustomerOrderImportsController::PROCESS_NAME,
      description: 'Trailing 30-Day Orders XLS from PDI. Creates or updates customer orders.' },
    { group: 'Regular', title: 'Link ODOR Products', icon: 'bi-link-45deg',
      path: :product_code_links_path,
      description: 'Match imported order product codes to MRP products.' },
    { group: 'Regular', title: 'PDI Master Data', icon: 'bi-cloud-download',
      path: :new_pdi_master_data_import_path,
      process: PdiMasterDataImportsController::PROCESS_NAME,
      description: 'Customers, ship-tos, terminals and products straight from the PDI web service.' },
    { group: 'Regular', title: 'PDI Products', icon: 'bi-box-seam',
      path: :new_pdi_product_import_path,
      process: PdiProductImportsController::PROCESS_NAME,
      description: 'Master product list from a PDI SQL export. Adds new products and updates existing ones.' },
    { group: 'Regular', title: 'PDI FI Inventory', icon: 'bi-upload',
      path: :new_pdi_inventory_import_path,
      process: PdiInventoryImportsController::PROCESS_NAME,
      description: 'FI (fuel) Inventory Report from PDI. Syncs tank stock by product and site; also runs daily.' },
    { group: 'Regular', title: 'Warehouse Inventory', icon: 'bi-boxes',
      path: :new_inventory_import_path,
      description: 'Warehouse inventory report from PDI. Updates stock by part number and site.' },
    { group: 'Regular', title: 'Purchase Orders (Warehouse Tx Report)', icon: 'bi-bag-plus',
      path: :new_purchase_order_imports_path,
      process: PurchaseOrderImportsController::PROCESS_NAME,
      description: 'PDI Warehouse Transaction Report (XLS/XLSX). Imports purchase orders.' },
    { group: 'Setup & history', title: 'Purchase Order History', icon: 'bi-bag-check',
      path: :new_pdi_purchase_order_import_path,
      process: PdiPurchaseOrderImportsController::PROCESS_NAME,
      description: 'Historical purchase orders with lines, vendors, costs and status from PDI.' },
    { group: 'Setup & history', title: 'Warehouse Transaction History', icon: 'bi-clock-history',
      path: :new_warehouse_transaction_import_path,
      process: WarehouseTransactionImportsController::PROCESS_NAME,
      description: 'One-time import of historical PDI warehouse transactions into inventory activity.' },
    { group: 'Setup & history', title: 'Bill of Materials', icon: 'bi-diagram-3',
      path: :new_bom_import_path,
      process: BomImportsController::PROCESS_NAME,
      description: 'BOMs from a PDI SQL export CSV.' },
    { group: 'Setup & history', title: 'Repack Batches', icon: 'bi-recycle',
      path: :new_repack_batch_import_path,
      process: RepackBatchImportsController::PROCESS_NAME,
      description: 'Historical repack batches as production orders. No stock adjustments.' },
    { group: 'Setup & history', title: 'Min/Max Levels', icon: 'bi-sliders2',
      path: :new_min_max_import_path,
      process: MinMaxImportsController::PROCESS_NAME,
      description: 'Reorder points and max stock from the Inventory Min-Max sheet.' },
    { group: 'Setup & history', title: 'Vendor Freight Terms', icon: 'bi-truck-flatbed',
      path: :new_vendor_freight_term_import_path,
      process: VendorFreightTermImportsController::PROCESS_NAME,
      description: 'Freight terms per vendor.' }
  ].freeze

  def index
    @imports = IMPORTS
    names = IMPORTS.map { |i| i[:process] }.compact
    @last_logs = SyncLog.where(process_name: names)
                        .select('DISTINCT ON (process_name) sync_logs.*')
                        .order(:process_name, started_at: :desc)
                        .index_by(&:process_name)
  end
end
