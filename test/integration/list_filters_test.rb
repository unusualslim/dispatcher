require 'test_helper'

# Products and Customers list filters, sorting, and each user's remembered filters.
class ListFiltersTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "admin-#{SecureRandom.hex(3)}@example.com", password: 'password123', role: 'admin')
    sign_in @user
    LocationCategory.find_or_create_by!(id: 2) { |c| c.name = 'Destination' }
  end

  def product_rows
    response.body.scan(/product-main-row" data-product-id="([^"]+)"/).flatten
  end

  def names_in_body(*names)
    names.select { |name| response.body.include?(name) }
  end

  test 'products: several categories, BOM, sales filters and both sort directions' do
    gas = Product.create!(id: 'QQ-GAS', name: 'Qq Gasoline', category: 'QQ GAS', unit_of_measurement: 'GA')
    defp = Product.create!(id: 'QQ-DEF', name: 'Qq Def Jug', category: 'QQ DEF', unit_of_measurement: '2/2.5')
    Product.create!(id: 'QQ-OIL', name: 'Qq Motor Oil', category: 'QQ OIL')
    ProductComponent.create!(product: defp, component_product: gas, quantity_per_unit: 1)
    order = CustomerOrder.create!(location: Location.create!(company_name: 'Qq Yard', location_category_id: 2),
                                  order_status: 'open_order', order_date: 1.month.ago)
    order.customer_order_products.create!(product_id: gas.id, product_name: gas.id, quantity: 5)

    get products_path(filtered: 1, query: 'Qq', category: ['QQ GAS', 'QQ DEF'])
    assert_equal %w[QQ-DEF QQ-GAS], product_rows

    get products_path(filtered: 1, query: 'Qq', bom: 'with')
    assert_equal %w[QQ-DEF], product_rows

    get products_path(filtered: 1, query: 'Qq', sales: '3')
    assert_equal %w[QQ-GAS], product_rows
    get products_path(filtered: 1, query: 'Qq', sales: 'never', unit: '2/2.5')
    assert_equal %w[QQ-DEF], product_rows

    get products_path(filtered: 1, query: 'Qq', sort: 'id_desc')
    assert_equal %w[QQ-OIL QQ-GAS QQ-DEF], product_rows
    get products_path(filtered: 1, query: 'Qq', sort: 'unit_asc')
    assert_equal %w[QQ-OIL QQ-DEF QQ-GAS], product_rows, 'blank unit first, then 2/2.5, GA'
  end

  test 'customers: PDI, activity and state filters, sorted by last order' do
    yard = Location.create!(company_name: 'Ww Yard', city: 'Albany', state: 'GA', location_category_id: 2)
    linked = Customer.create!(name: 'Ww Linked', pdi_customer_id: '4242', preferred_contact_method: 'no preference')
    idle = Customer.create!(name: 'Ww Idle', preferred_contact_method: 'no preference')
    Customer.create!(name: 'Ww Florida', preferred_contact_method: 'no preference')
            .locations << Location.create!(company_name: 'Ww FL', state: 'FL', location_category_id: 2)
    CustomerOrder.create!(customer: linked, location: yard, order_status: 'open_order', order_date: 2.days.ago)
    CustomerOrder.create!(customer: idle, location: yard, order_status: 'billed', order_date: 2.years.ago)
    all = ['Ww Linked', 'Ww Idle', 'Ww Florida']

    get customers_path(filtered: 1, search: 'Ww', pdi: 'linked')
    assert_equal ['Ww Linked'], names_in_body(*all)

    get customers_path(filtered: 1, search: 'Ww', activity: 'idle_12')
    assert_equal ['Ww Idle', 'Ww Florida'], names_in_body(*all)

    get customers_path(filtered: 1, search: 'Ww', state: 'GA')
    assert_equal ['Ww Linked', 'Ww Idle'], names_in_body(*all)

    get customers_path(filtered: 1, search: 'Ww', sort: 'last_order_desc')
    assert_operator response.body.index('Ww Linked'), :<, response.body.index('Ww Idle')
    assert_operator response.body.index('Ww Idle'), :<, response.body.index('Ww Florida'), 'never ordered sorts last'
  end

  test 'a bare visit restores the user\'s last filters; Clear forgets them' do
    get customers_path(filtered: 1, pdi: 'unlinked', sort: 'name_desc')
    assert_equal({ 'filtered' => '1', 'pdi' => 'unlinked', 'sort' => 'name_desc' },
                 @user.reload.list_filters['customers'])

    get customers_path
    assert_redirected_to customers_path(filtered: 1, pdi: 'unlinked', sort: 'name_desc')

    get customers_path(reset: 1)
    assert_response :success
    assert_nil @user.reload.list_filters['customers']
    get customers_path
    assert_response :success
  end
end
