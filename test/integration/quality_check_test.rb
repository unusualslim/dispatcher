require 'test_helper'

class QualityCheckTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers
  fixtures :products, :product_components, :locations, :location_categories

  setup do
    @admin = User.create!(email: 'admin-qc@example.com', password: 'password123', role: 'admin', first_name: 'Q',
                          last_name: 'Tester')
    sign_in @admin
    @product = products(:def_finished)
    @ph = @product.quality_specs.create!(name: 'pH', target_min: 9.5, target_max: 10.5, position: 1)
    @sulfur = @product.quality_specs.create!(name: 'Total Sulfur', test_method: 'ASTM D5453', unit: 'mg/kg',
                                             target_max: 0.5, position: 2, section: 'Elemental Analysis')
    @look = @product.quality_specs.create!(name: 'Appearance', result_type: 'pass_fail', expected: 'Clear', position: 3)
    @location = locations(:warehouse)
    @po = ProductionOrder.create!(product: @product, location: @location, qty_to_make: 100, status: 'in_progress')
    @po.build_components_from_bom!
    @po.save!
  end

  def record(values)
    patch record_quality_production_order_path(@po), params: { results: values }
  end

  def status!(status)
    patch production_order_path(@po), params: { production_order: { status: status } }
    @po.reload
  end

  test 'quality check flow: lot, results, completion, inventory' do
    status!('quality_check')
    assert_equal 'quality_check', @po.status
    assert_match(/\AFPS-DEFFIN-\d{8}-001\z/, @po.lot_number)

    record(@ph.id => { value: '9.8' }, @sulfur.id => { value: '< 0.5' })
    status!('completed')
    assert_equal 'quality_check', @po.status, 'blocked: Appearance not recorded'
    assert_match 'Record these quality checks first: Appearance', flash[:alert]

    record(@look.id => { value: 'fail' }, @ph.id => { value: '11' })
    @po.update!(total_qty_produced: 100)
    status!('completed')
    assert_equal 'completed', @po.status, 'out-of-range results still complete'
    assert_equal({ 'pH' => false, 'Total Sulfur' => true, 'Appearance' => false },
                 @po.quality_results.to_h { |r| [r.name, r.in_range] })

    assert_equal 100, LocationProduct.find_by(location: @location, product: @product).quantity
    status!('quality_check') # reopen reverses the inventory
    assert_equal 0, LocationProduct.find_by(location: @location, product: @product).quantity
  end

  test 'completion needs a quantity produced' do
    status!('quality_check')
    record(@ph.id => { value: '10' }, @sulfur.id => { value: '0.1' }, @look.id => { value: 'pass' })
    status!('completed')

    assert_equal 'quality_check', @po.status
    assert_match 'Total qty produced is needed to complete', flash[:alert]
  end

  test 'exceptions are reviewed by Production approvers' do
    @po.update!(status: 'quality_check')
    record(@ph.id => { value: '12' })
    result = @po.quality_results.first

    get quality_exceptions_path
    assert_select 'td', /12/

    patch review_quality_exception_path(result), params: { resolution: 'Re-blended and retested at 10.1' }
    assert result.reload.reviewed?
    assert_equal @admin, result.reviewed_by

    sign_in User.create!(email: 'staff-qc@example.com', password: 'password123', role: 'staff',
                         permissions: { 'production' => 'edit' })
    other = @po.quality_results.create!(QualityResult.copy_spec(@sulfur).merge(value: 3, tested_at: Time.current))
    patch review_quality_exception_path(other), params: { resolution: 'nope' }
    assert_not other.reload.reviewed?
  end

  test 'printable certificate lists methods, ranges and results' do
    @product.update!(coa_note: 'Methods based on ISO 22241-2')
    @po.update!(status: 'quality_check')
    record(@ph.id => { value: '9.8' }, @sulfur.id => { value: '< 0.5' }, @look.id => { value: 'pass' })

    get quality_certificate_production_order_path(@po)
    assert_response :success
    assert_select 'h1', 'Certificate of Analysis'
    assert_select 'td', 'ASTM D5453'
    assert_select 'td', '< 0.5'
    assert_match 'All 3 tests within specification', response.body
    assert_select 'tr.section td', 'Elemental Analysis'
    assert_match 'Methods based on ISO 22241-2', response.body
  end

  test 'products save their quality checks' do
    patch product_path(@product), params: { product: { quality_specs_attributes: {
      '0' => { name: 'Viscosity', test_method: 'ASTM D445', result_type: 'numeric', unit: 'cSt', target_min: '2',
               target_max: '3' }
    } } }
    assert_equal 'Viscosity', @product.quality_specs.reload.last.name
  end

  test 'quantity produced is editable on the order page until completion' do
    get production_order_path(@po)
    assert_select '#qty-produced-form input[name="production_order[total_qty_produced]"]'

    patch production_order_path(@po), params: { production_order: { total_qty_produced: '98' } }
    assert_redirected_to production_order_path(@po)
    assert_equal 98, @po.reload.total_qty_produced

    done = ProductionOrder.create!(product: @product, status: 'completed', total_qty_produced: 50)
    get production_order_path(done)
    assert_select '#qty-produced-form', 0
  end
end
