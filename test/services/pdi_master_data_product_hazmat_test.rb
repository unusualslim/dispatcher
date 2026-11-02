require 'test_helper'

# Hazmat data for the bill of lading: PDI's master data sends it for warehouse products only.
class PdiMasterDataProductHazmatTest < ActiveSupport::TestCase
  HAZMAT = '<HazardousMaterial>Yes</HazardousMaterial>' \
           '<HazardousMaterialNotes>UN1230, Methanol, 3, PG II</HazardousMaterialNotes>'.freeze

  setup do
    LocationCategory.find_or_create_by!(id: 1) { |c| c.name = 'Origin' }
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
  end

  test 'takes the hazmat flag and notes from PDI warehouse products, keeping app descriptions when notes are blank' do
    xml = file_fixture('pdi_master_data.xml').read.sub('</ProductPackage>', "</ProductPackage>#{HAZMAT}")
    PdiMasterDataImportService.call(xml)
    assert_equal [true, 'UN1230, Methanol, 3, PG II'], Product.find('DEF25').values_at(:hazmat, :hazmat_description)

    Product.find('101').update!(hazmat: true, hazmat_description: 'UN1203, Gasoline, 3, PG II')
    PdiMasterDataImportService.call(xml.sub(%r{<HazardousMaterialNotes>.*</HazardousMaterialNotes>}, ''))
    assert_equal 'UN1230, Methanol, 3, PG II', Product.find('DEF25').hazmat_description
    # PDI sends no hazmat data for fuel products, so the app's stays.
    assert_equal [true, 'UN1203, Gasoline, 3, PG II'], Product.find('101').values_at(:hazmat, :hazmat_description)

    # A product flagged in the app stays flagged when PDI says No.
    PdiMasterDataImportService.call(xml.sub('<HazardousMaterial>Yes', '<HazardousMaterial>No'))
    assert Product.find('DEF25').hazmat
  end
end
