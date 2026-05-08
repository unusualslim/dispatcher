require 'csv'
require 'net/ftp'
require 'stringio'

class PdiExportJob < ApplicationJob
  queue_as :default

  PDI_SITE_ID = 2

  def perform(purchase_order_id)
    po = PurchaseOrder.includes(:product, :vendor).find_by(id: purchase_order_id)
    return unless po

    csv_content = generate_csv(po)
    filename    = "PO_#{po.id}_#{Time.now.strftime('%Y%m%d%H%M%S')}.csv"

    upload_to_ftp(filename, csv_content)

    Rails.logger.info "[PdiExportJob] Uploaded #{filename} to FTP for PO ##{po.id}"
  rescue => e
    Rails.logger.error "[PdiExportJob] Failed to export PO ##{purchase_order_id}: #{e.message}"
    raise  # re-raise so ActiveJob retries
  end

  private

  def generate_csv(po)
    vendor   = po.vendor
    product  = po.product
    today    = Date.today.strftime('%-m/%-d/%Y')
    delivery = (po.expected_delivery_date || Date.today).strftime('%-m/%-d/%Y')
    total    = po.total_cost&.to_f || 0

    CSV.generate do |out|
      out << ['REM', 'Vendor ID', 'PO Number', 'Business Date', 'Order Date', 'Delivery Date', '', '', '', '', '', '', 'Invoice Total']
      out << ['POH', vendor.pdi_vendor_id, '', today, today, delivery, '', '', '', '', '', '', total]
      out << ['REM', 'Site ID', 'Product ID', 'Package Code', '', '', 'Inventory Package Qty', 'Invoice Qty', 'Delivery qty', '', 'Billing Units Costs', '', '']
      out << ['POD', PDI_SITE_ID, product&.id, product&.pdi_package_code, '', '', po.quantity.to_f, po.quantity.to_f, '', '', po.unit_cost&.to_f, '', '']
    end
  end

  def upload_to_ftp(filename, content)
    host     = ENV.fetch('PDI_FTP_HOST')
    user     = ENV.fetch('PDI_FTP_USER')
    password = ENV.fetch('PDI_FTP_PASSWORD')
    path     = ENV.fetch('PDI_FTP_PATH', '/')

    Net::FTP.open(host, username: user, password: password) do |ftp|
      ftp.passive = true
      ftp.chdir(path) unless path == '/'
      ftp.storbinary("STOR #{filename}", StringIO.new(content), Net::FTP::DEFAULT_BLOCKSIZE)
    end
  end
end
