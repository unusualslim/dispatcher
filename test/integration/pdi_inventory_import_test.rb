require 'test_helper'

class PdiInventoryImportTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  test 'manual FI upload syncs stock and logs the run' do
    sign_in User.create!(email: 'admin-fi@example.com', password: 'password123', role: 'admin')
    product = Product.create!(id: '401', name: 'ULSD', category: 'DIESEL')
    file = Tempfile.new(['fi', '.csv'])
    row = Array.new(19)
    row[0] = '3.0'
    row[1] = '401'
    row[14] = '100'
    row[18] = '480'
    CSV.open(file.path, 'w') { |csv| csv << ['Site 0002 - FPS-Main'] << row }

    post pdi_inventory_import_path, params: { file: Rack::Test::UploadedFile.new(file.path, 'text/csv') }

    assert_redirected_to new_pdi_inventory_import_path
    assert_equal 100, product.reload.current_stock
    log = SyncLog.find_by!(process_name: PdiInventoryImportsController::PROCESS_NAME)
    assert_equal ['success', 1], [log.status, log.records_updated]
    assert_match 'No location with PDI site number: 0002 FPS-Main', log.warnings
  end
end
