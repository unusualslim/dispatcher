require 'test_helper'

class VendorItemPricesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @product = Product.create!(id: 'VIP-1', name: 'Urea')
    @vendor = Vendor.create!(id: 'VIP-V', name: 'Urea Co')
    @product.set_vendors_in_order([@vendor.id])
    sign_in User.create!(email: 'vip-admin@example.com', password: 'password123', role: 'admin')
  end

  test 'several prices per vendor are added, shown and kept when the vendor list is saved again' do
    link = @product.product_vendors.first
    post product_vendor_item_prices_path(@product), params: { product_vendor_id: link.id, vendor_part_number: 'U-50',
                                                              description: '50 lb bag', unit_cost: '12.5' }
    post product_vendor_item_prices_path(@product), params: { product_vendor_id: link.id, vendor_part_number: 'U-TOTE',
                                                              description: 'Tote', min_quantity: '10', unit_cost: '11' }
    assert_equal 2, link.prices.count

    get product_path(@product)
    assert_select 'td', text: 'U-TOTE'

    other = Vendor.create!(id: 'VIP-V2', name: 'Backup Co')
    @product.set_vendors_in_order([other.id, @vendor.id])
    assert_equal 2, @product.product_vendors.find_by!(vendor: @vendor).prices.count
    assert_equal 2, @product.product_vendors.find_by!(vendor: @vendor).priority

    delete product_vendor_item_price_path(@product, link.prices.first)
    assert_equal 1, link.prices.count
  end
end
