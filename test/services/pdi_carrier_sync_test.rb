require 'test_helper'

class PdiCarrierSyncTest < ActiveSupport::TestCase
  def master_xml
    file_fixture('pdi_master_data.xml').read
  end

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
  end

  test 'syncs PDI carriers by ERPNumber' do
    PdiCarrier.create!(pdi_carrier_id: '1590', name: 'Old Dominion')

    result = PdiMasterDataImportService.call(master_xml)

    assert_equal 'Five Points Logistics, LLC', PdiCarrier.name_for('1514')
    assert_equal 'Old Dominion Freight Line, Inc.', PdiCarrier.name_for('1590')
    assert_equal [1, 1], [result.count(:carriers, :create), result.count(:carriers, :update)]
  end
end
