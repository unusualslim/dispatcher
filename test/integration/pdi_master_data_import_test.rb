require 'test_helper'
require 'minitest/mock'

class PdiMasterDataImportTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  # Stands in for PdiWebService so no request leaves the test.
  class FakePdi
    def initialize(xml: nil, credit: nil)
      @xml = xml
      @credit = credit
    end

    def master_data
      @xml
    end

    def credit_check(_customer_id)
      @credit
    end
  end

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @admin = User.create!(email: "admin-#{SecureRandom.hex(3)}@example.com", password: 'password123', role: 'admin')
  end

  def with_pdi(fake, &)
    PdiWebService.stub(:configured?, true) { PdiWebService.stub(:new, fake, &) }
  end

  test 'admin previews PDI master data, then confirms the import' do
    sign_in @admin
    get new_pdi_master_data_import_path
    assert_response :success

    with_pdi(FakePdi.new(xml: file_fixture('pdi_master_data.xml').read)) do
      post preview_pdi_master_data_import_path
      assert_response :success
      assert_select 'h1', 'Preview PDI Master Data'
      assert_nil Customer.find_by(pdi_customer_id: '2362'), 'preview saves nothing'

      post pdi_master_data_import_path
    end

    assert_redirected_to new_pdi_master_data_import_path
    assert Customer.exists?(pdi_customer_id: '2362')
    log = SyncLog.for_process(PdiMasterDataSyncJob::PROCESS_NAME).first
    assert_equal 'success', log.status
    get download_pdi_master_data_import_path(log_id: log.id)
    assert_includes Zlib.gunzip(response.body), '<PDIMasterFile>'
  end

  test 'staff without admin cannot run it' do
    sign_in User.create!(email: 'sales@example.com', password: 'password123', role: 'staff',
                         permissions: { 'sales' => 'edit' })
    post preview_pdi_master_data_import_path
    assert_response :redirect
    assert_nil Customer.find_by(pdi_customer_id: '2362')
  end

  test 'credit frame shows a hold and an order that exceeds available credit' do
    sign_in User.create!(email: 'sales@example.com', password: 'password123', role: 'staff',
                         permissions: { 'sales' => 'view' })
    customer = Customer.create!(name: 'Southern Performance Chemical', pdi_customer_id: '2362',
                                preferred_contact_method: 'no preference')
    credit = PdiWebService::CreditCheck.new(credit_status: 1, available_credit: BigDecimal('-53727.98'),
                                            credit_limit: BigDecimal('250000'), hold_credit_limit: BigDecimal('250000'),
                                            account_status: 0)

    get customer_path(customer)
    assert_select "turbo-frame#pdi_credit[src='#{pdi_credit_customer_path(customer)}'][loading=lazy]"

    with_pdi(FakePdi.new(credit: credit)) { get pdi_credit_customer_path(customer, amount: '67881') }

    assert_response :success
    assert_select 'turbo-frame#pdi_credit .badge', 'Credit Hold'
    assert_select 'turbo-frame#pdi_credit', /-\$53,727\.98/
    assert_select 'turbo-frame#pdi_credit .badge', 'Exceeds available credit'
  end
end
