require 'test_helper'

class ProductMergeTest < ActiveSupport::TestCase
  setup do
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
    @site = Location.create!(company_name: 'PM Site', location_category_id: 2)
    @old = Product.create!(id: 'PM-OLD', name: 'DEF (bulk) old')
    @new = Product.create!(id: 'PM-901', name: 'Bulk DEF')
  end

  test 'history, tanks and stock rows follow; the old product is left inactive' do
    order = CustomerOrder.create!(location: @site, order_date: Date.current)
    line = order.customer_order_products.create!(product: @old, quantity: 500)
    tank = Tank.create!(location: @site, product: @old, name: 'DEF', capacity_gallons: 1000)
    row = LocationProduct.create!(location: @site, product: @old, max_capacity: 1000, 'uleage_90' => 85)
    vendor = Vendor.create!(id: 'PM-V', name: 'Urea Co')
    ProductVendor.create!(product: @old, vendor: vendor)

    merge = ProductMerge.new(@old, @new)
    assert_equal 1, merge.counts['Order lines']
    merge.merge!

    assert_equal @new.id, line.reload.product_id
    assert_equal @new.id, tank.reload.product_id
    assert_equal @new.id, row.reload.product_id
    assert_equal [vendor.id], @new.product_vendors.pluck(:vendor_id)
    assert_not @old.reload.active
  end

  test "the target's own rows win: duplicate links dropped, tank settings fill only blanks, BOM stays put" do
    vendor = Vendor.create!(id: 'PM-V2', name: 'Urea Co')
    ProductVendor.create!(product: @old, vendor: vendor)
    ProductVendor.create!(product: @new, vendor: vendor)
    LocationProduct.create!(location: @site, product: @old, max_capacity: 1000, 'uleage_90' => 85)
    kept = LocationProduct.create!(location: @site, product: @new, max_capacity: 2000)
    urea = Product.create!(id: 'PM-UREA', name: 'Urea')
    old_bom = ProductComponent.create!(product: @old, component_product: urea, quantity_per_unit: 1)
    ProductComponent.create!(product: @new, component_product: urea, quantity_per_unit: 2)

    merge = ProductMerge.new(@old, @new)
    assert_equal({ 'BOM lines' => 1 }, merge.kept_on_source)
    merge.merge!

    assert_equal 1, ProductVendor.where(vendor: vendor).count
    assert_equal [kept.id], LocationProduct.where(location: @site).pluck(:id)
    assert_equal [2000, 85], [kept.reload.max_capacity, kept.uleage_90]
    assert_equal @old.id, old_bom.reload.product_id
  end

  test 'refused while the old product holds stock, or into itself' do
    LocationProduct.create!(location: @site, product: @old, quantity: 5)
    assert_raises(ArgumentError) { ProductMerge.new(@old, @new) }
    assert_raises(ArgumentError) { ProductMerge.new(@new, @new) }
  end
end
