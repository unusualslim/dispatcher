require 'test_helper'

class PdiMasterDataImportServiceTest < ActiveSupport::TestCase
  def master_xml
    file_fixture('pdi_master_data.xml').read
  end

  setup do
    @destination = LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @origin = LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
  end

  test 'preview saves nothing and predicts the run' do
    preview = PdiMasterDataImportService.new(master_xml).preview

    assert_equal 0, Customer.where.not(pdi_customer_id: nil).count
    assert_equal 0, Product.where(id: %w[101 DEF25]).count
    run = PdiMasterDataImportService.call(master_xml)
    PdiMasterDataImportService::SECTIONS.each_key do |section|
      %i[create link update skip].each do |action|
        assert_equal run.count(section, action), preview.count(section, action), "#{section} #{action}"
      end
    end
  end

  test 'creates customers, ship-tos and products, sharing one location per place' do
    result = PdiMasterDataImportService.call(master_xml)

    spc = Customer.find_by!(pdi_customer_id: '2362')
    assert_equal ['Southern Performance Chemical', '(678) 354-7167'], [spc.name, spc.phone]
    assert_nil Customer.find_by(pdi_customer_id: '500'), 'inactive customers are not added'

    melbourne = CustomerLocation.find_by!(customer: spc, pdi_location_id: '12').location
    assert_equal ['1605 Lake Street', '32901', @destination.id],
                 [melbourne.address, melbourne.zip, melbourne.location_category_id]

    # Both customers' FPS Warehouse ship-tos point at the same app location.
    martin = Customer.find_by!(pdi_customer_id: '1935')
    assert_equal CustomerLocation.find_by!(customer: spc, pdi_location_id: '100').location_id,
                 CustomerLocation.find_by!(customer: martin, pdi_location_id: '100').location_id
    assert_equal 1, result.count(:ship_tos, :link)
    assert_nil CustomerLocation.find_by(pdi_location_id: '7'), 'inactive ship-tos are not added'

    assert_equal %w[101 DEF25], Product.where(id: %w[101 DEF25 OLD1]).order(:id).pluck(:id)
    assert_equal ['CS', 45.5], [Product.find('DEF25').pdi_package_code, Product.find('DEF25').weight.to_f]
    assert_equal 'fuel', ReportingGroup.find_by!(name: 'GASOLINE').item_type
  end

  test 'a second run changes nothing' do
    PdiMasterDataImportService.call(master_xml)
    result = PdiMasterDataImportService.new(master_xml).preview

    %i[create link update error].each { |action| assert_equal 0, result.total(action), action }
  end

  test 'links existing customers and their order locations without renaming them' do
    spc = Customer.create!(name: 'Southern Performance Chemical', preferred_contact_method: 'no preference')
    legacy = Location.create!(company_name: '12 - Southern Performance Chemical', location_category_id: 2)
    CustomerLocation.create!(customer: spc, location: legacy)

    result = PdiMasterDataImportService.call(master_xml)

    assert_equal '2362', spc.reload.pdi_customer_id
    assert_equal 'link', result.for(:customers, :link).first.action.to_s
    link = CustomerLocation.find_by!(customer: spc, location: legacy)
    assert_equal '12', link.pdi_location_id
    legacy.reload
    assert_equal '12 - Southern Performance Chemical', legacy.company_name, 'existing names are kept'
    assert_equal ['1605 Lake Street', 'Fort Valley', '32901'], [legacy.address, legacy.city, legacy.zip],
                 'blanks are filled'
  end

  test 'links terminals by name and never creates them' do
    terminal = Location.create!(company_name: 'TransMontaigne - Americus', location_category_id: 1)

    result = PdiMasterDataImportService.call(master_xml)

    assert_equal '2505', terminal.reload.pdi_terminal_id
    assert_equal ['9999'], result.for(:terminals, :skip).map(&:key)
    assert_equal 1, Location.where(location_category_id: 1).count
  end

  test 'PDI names win for linked customers and products' do
    PdiMasterDataImportService.call(master_xml)
    Customer.find_by!(pdi_customer_id: '2362').update!(name: 'SPC (typo)')
    Product.find('101').update!(name: 'Regular')

    result = PdiMasterDataImportService.call(master_xml)

    assert_equal 'Southern Performance Chemical', Customer.find_by!(pdi_customer_id: '2362').name
    assert_equal '87 Regular w/10% Ethanol', Product.find('101').name
    assert_equal 1, result.count(:customers, :update)
    assert_equal 1, result.count(:products, :update)
  end

  test 'marks an existing product inactive in PDI as inactive, changing nothing else, and back again' do
    Product.where(id: 'OLD1').delete_all
    old = Product.create!(id: 'OLD1', name: 'Our retired DEF', category: 'Legacy')

    result = PdiMasterDataImportService.call(master_xml)

    assert_equal [false, 'Our retired DEF', 'Legacy'], old.reload.values_at(:active, :name, :category)
    change = result.for(:products, :update).find { |c| c.key == 'OLD1' }
    assert_equal [{ active: false }, 'Inactive in PDI'], [change.changes, change.note]
    assert_equal :unchanged, PdiMasterDataImportService.call(master_xml).for(:products, :unchanged, :update)
                                                       .find { |c| c.key == 'OLD1' }.action

    PdiMasterDataImportService.call(master_xml.sub('<Active>No</Active>', '<Active>Yes</Active>'))
    assert_equal [true, 'Retired', 'DEF'], old.reload.values_at(:active, :name, :category)
  end

  test 'links and deactivates a customer inactive in PDI, leaving its ship-tos alone' do
    gone = Customer.create!(name: 'Gone Away LLC', phone: '555-0100', preferred_contact_method: 'no preference')

    assert_no_difference -> { Location.where(company_name: 'Gone Away Yard').count } do
      PdiMasterDataImportService.call(master_xml)
    end

    assert_equal ['500', false, '555-0100'], gone.reload.values_at(:pdi_customer_id, :active, :phone)
    assert_not CustomerLocation.exists?(customer: gone)

    PdiMasterDataImportService.call(master_xml.sub('<AccountStatus>Inactive</AccountStatus>',
                                                   '<AccountStatus>Active</AccountStatus>'))
    assert gone.reload.active
    assert CustomerLocation.exists?(customer: gone, pdi_location_id: '1')
  end
end
