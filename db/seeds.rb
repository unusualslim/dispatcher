# Perry Brothers Oil — Realistic Seed Data
# Americus / Albany, Georgia fuel delivery operation
#
# WARNING: This seed file destroys all existing data.
# It is intended for local development only and will NEVER run in production.

if Rails.env.production?
  puts 'Skipping seeds in production environment.'
  return
end

puts 'Clearing existing data...'
QuoteProduct.destroy_all
Quote.destroy_all
PricingRuleProduct.destroy_all
PricingRule.destroy_all
StandardCostHistory.destroy_all
Comment.destroy_all
WorkOrder.destroy_all
DispatchMessage.destroy_all
DispatchCustomerOrder.destroy_all
CustomerOrderProduct.destroy_all
CustomerOrder.destroy_all
Dispatch.destroy_all
ProductionOrderBatch.destroy_all
ProductionOrderComponent.destroy_all
ProductionOrder.destroy_all
InventoryTransaction.destroy_all
PurchaseOrder.destroy_all
LocationContact.destroy_all
LocationProduct.destroy_all
CustomerLocation.destroy_all
PhoneNumber.destroy_all
Customer.destroy_all
Location.destroy_all
LocationCategory.destroy_all
ProductComponent.destroy_all
ProductCostLine.destroy_all
Product.destroy_all
Thing.destroy_all
Vendor.destroy_all
Announcement.destroy_all
User.destroy_all

puts 'Seeding location categories...'
origin_cat      = LocationCategory.create!(id: 1, name: 'Origin')       # app expects 1 = origin
destination_cat = LocationCategory.create!(id: 2, name: 'Destination')  # and 2 = destination

# ---------------------------------------------------------------------------
# PRODUCTS
# ---------------------------------------------------------------------------
puts 'Seeding reporting groups...'
[['Consumables', false], ['Labor', true], ['Overhead', false]].each_with_index do |(name, labor), i|
  ReportingGroup.find_or_create_by!(name: name) do |g|
    g.assign_attributes(item_type: 'non_inventory', labor: labor, position: i + 1)
  end
end

puts 'Seeding products...'
products = {
  regular: Product.create!(id: 'REG001', name: 'Regular', unit_of_measurement: 'gallons', weight: 6.073),
  plus: Product.create!(id: 'PLUS001', name: 'Plus', unit_of_measurement: 'gallons', weight: 6.073),
  super_fuel: Product.create!(id: 'SUP001',  name: 'Super', unit_of_measurement: 'gallons', weight: 6.073),
  def_fluid: Product.create!(id: 'DEF001', name: 'DEF', unit_of_measurement: 'gallons', weight: 9.08),
  uls: Product.create!(id: 'ULS001', name: 'ULS', unit_of_measurement: 'gallons', weight: 7.05),
  dyed_uls: Product.create!(id: 'DULS001', name: 'Dyed ULS', unit_of_measurement: 'gallons', weight: 7.05),
  reg_e10: Product.create!(id: 'E10001', name: 'Reg-E10', unit_of_measurement: 'gallons', weight: 6.10),
  eth_regular: Product.create!(id: 'ETH001', name: 'Eth-Regular', unit_of_measurement: 'gallons', weight: 6.10)
}

# ---------------------------------------------------------------------------
# VENDORS
# ---------------------------------------------------------------------------
puts 'Seeding vendors...'
vendors = [
  Vendor.create!(id: 'V001', name: 'Mansfield Oil Company'),
  Vendor.create!(id: 'V002', name: 'Pilot Flying J Supply'),
  Vendor.create!(id: 'V003', name: 'Hunt Refining Co.'),
  Vendor.create!(id: 'V004', name: 'Gulf Oil Partners')
]

# ---------------------------------------------------------------------------
# TRUCKS & TRAILERS (Things)
# ---------------------------------------------------------------------------
puts 'Seeding fleet...'
trucks = [
  Thing.create!(name: 'Truck 101 – Kenworth T680', category: 'truck'),
  Thing.create!(name: 'Truck 102 – Peterbilt 389', category: 'truck'),
  Thing.create!(name: 'Truck 103 – Freightliner Cascadia', category: 'truck'),
  Thing.create!(name: 'Truck 104 – Kenworth W900', category: 'truck'),
  Thing.create!(name: 'Truck 105 – International LT', category: 'truck')
]

trailers = [
  Thing.create!(name: 'Trailer 201 – 9000 gal Tanker', category: 'trailer'),
  Thing.create!(name: 'Trailer 202 – 7500 gal Tanker', category: 'trailer'),
  Thing.create!(name: 'Trailer 203 – 9000 gal Tanker', category: 'trailer'),
  Thing.create!(name: 'Trailer 204 – 6000 gal Tanker', category: 'trailer')
]

# ---------------------------------------------------------------------------
# USERS
# ---------------------------------------------------------------------------
puts 'Seeding users...'
admin = User.create!(
  email: 'admin@perrybrothersoil.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'John',
  last_name: 'Perry',
  phone_number: '(229) 924-1100',
  role: 'admin'
)

dispatcher_user = User.create!(
  email: 'dispatch@perrybrothersoil.com',
  password: 'password123',
  password_confirmation: 'password123',
  first_name: 'Lisa',
  last_name: 'Hargrove',
  phone_number: '(229) 924-1101',
  role: 'admin'
)

drivers = [
  User.create!(
    email: 'rbrown@perrybrothersoil.com',
    password: 'password123', password_confirmation: 'password123',
    first_name: 'Ray', last_name: 'Brown',
    phone_number: '(229) 555-0201', role: 'worker',
    sms_opt_in: true, email_opt_in: false
  ),
  User.create!(
    email: 'twilliams@perrybrothersoil.com',
    password: 'password123', password_confirmation: 'password123',
    first_name: 'Tony', last_name: 'Williams',
    phone_number: '(229) 555-0202', role: 'worker',
    sms_opt_in: true, email_opt_in: false
  ),
  User.create!(
    email: 'djackson@perrybrothersoil.com',
    password: 'password123', password_confirmation: 'password123',
    first_name: 'Darrell', last_name: 'Jackson',
    phone_number: '(229) 555-0203', role: 'worker',
    sms_opt_in: true, email_opt_in: false
  ),
  User.create!(
    email: 'mthomas@perrybrothersoil.com',
    password: 'password123', password_confirmation: 'password123',
    first_name: 'Marcus', last_name: 'Thomas',
    phone_number: '(229) 555-0204', role: 'worker',
    sms_opt_in: false, email_opt_in: true
  ),
  User.create!(
    email: 'kmoore@perrybrothersoil.com',
    password: 'password123', password_confirmation: 'password123',
    first_name: 'Kevin', last_name: 'Moore',
    phone_number: '(229) 555-0205', role: 'worker',
    sms_opt_in: true, email_opt_in: false
  )
]

# ---------------------------------------------------------------------------
# ORIGIN LOCATIONS (fuel terminals / rack)
# ---------------------------------------------------------------------------
puts 'Seeding origin locations...'
origins = [
  Location.create!(
    company_name: 'Mansfield Terminal – Albany',
    address: '2400 Philema Rd S',
    city: 'Albany',
    state: 'GA',
    zip: '31701',
    phone_number: '(229) 435-7800',
    latitude: 31.5660, longitude: -84.1555,
    location_category: origin_cat,
    marker_color: 'blue'
  ),
  Location.create!(
    company_name: 'Hunt Refining Rack – Cordele',
    address: '1815 16th Ave E',
    city: 'Cordele',
    state: 'GA',
    zip: '31015',
    phone_number: '(229) 271-3900',
    latitude: 31.9649, longitude: -83.7754,
    location_category: origin_cat,
    marker_color: 'blue'
  ),
  Location.create!(
    company_name: 'Gulf Supply Terminal – Valdosta',
    address: '3200 Inner Perimeter Rd',
    city: 'Valdosta',
    state: 'GA',
    zip: '31601',
    phone_number: '(229) 241-0400',
    latitude: 30.8327, longitude: -83.2785,
    location_category: origin_cat,
    marker_color: 'blue'
  )
]

# ---------------------------------------------------------------------------
# CUSTOMERS
# ---------------------------------------------------------------------------
puts 'Seeding customers...'
customers = [
  Customer.create!(name: "Stuckey's Travel Center", email: 'ops@stuckeys-americus.com', phone: '(229) 924-3300',
                   preferred_contact_method: 'phone'),
  Customer.create!(name: 'Quick Trip #4481',            email: 'manager4481@qt.com',           phone: '(229) 883-1200',
                   preferred_contact_method: 'email'),
  Customer.create!(name: 'Murphy Express – Albany',     email: 'albany.ops@murphyusa.com',     phone: '(229) 430-5800',
                   preferred_contact_method: 'phone'),
  Customer.create!(name: 'Flash Foods #228',            email: 'store228@flashfoods.com',
                   phone: '(229) 468-2100', preferred_contact_method: 'email'),
  Customer.create!(name: 'Parker\'s Kitchen – Tifton',  email: 'tifton@parkerskitchen.com', phone: '(229) 386-7700',
                   preferred_contact_method: 'phone'),
  Customer.create!(name: 'Sunoco – Cordele',            email: 'cordele.sunoco@gmail.com',
                   phone: '(229) 271-0055', preferred_contact_method: 'no preference'),
  Customer.create!(name: 'BP – Americus',               email: 'bp.americus@gmail.com',
                   phone: '(229) 924-8810', preferred_contact_method: 'phone'),
  Customer.create!(name: 'Loves Travel Stop #542',      email: 'store542@loves.com',
                   phone: '(229) 924-0040', preferred_contact_method: 'email')
]

# ---------------------------------------------------------------------------
# DESTINATION LOCATIONS (customer delivery sites)
# ---------------------------------------------------------------------------
puts 'Seeding destination locations...'
dest_locations = [
  {
    customer: customers[0],
    location: Location.create!(
      company_name: "Stuckey's Travel Center",
      address: '1201 E Forsyth St', city: 'Americus', state: 'GA', zip: '31709',
      phone_number: '(229) 924-3300', latitude: 32.0724, longitude: -84.2158,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 20_000, uleage_90: 18_000, cutoff_percent: 10
    )
  },
  {
    customer: customers[1],
    location: Location.create!(
      company_name: 'QuikTrip #4481',
      address: '2814 Dawson Rd', city: 'Albany', state: 'GA', zip: '31707',
      phone_number: '(229) 883-1200', latitude: 31.5812, longitude: -84.1923,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 24_000, uleage_90: 21_600, cutoff_percent: 10
    )
  },
  {
    customer: customers[2],
    location: Location.create!(
      company_name: 'Murphy Express – Albany Walmart',
      address: '2601 Pointe North Blvd', city: 'Albany', state: 'GA', zip: '31721',
      phone_number: '(229) 430-5800', latitude: 31.6130, longitude: -84.2212,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 18_000, uleage_90: 16_200, cutoff_percent: 10
    )
  },
  {
    customer: customers[3],
    location: Location.create!(
      company_name: 'Flash Foods #228',
      address: '601 N Irwin Ave', city: 'Ocilla', state: 'GA', zip: '31774',
      phone_number: '(229) 468-2100', latitude: 31.5954, longitude: -83.2482,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 16_000, uleage_90: 14_400, cutoff_percent: 10
    )
  },
  {
    customer: customers[4],
    location: Location.create!(
      company_name: "Parker's Kitchen",
      address: '915 US-82 E', city: 'Tifton', state: 'GA', zip: '31794',
      phone_number: '(229) 386-7700', latitude: 31.4513, longitude: -83.4880,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 22_000, uleage_90: 19_800, cutoff_percent: 10
    )
  },
  {
    customer: customers[5],
    location: Location.create!(
      company_name: 'Sunoco – Cordele',
      address: '1405 E 16th Ave', city: 'Cordele', state: 'GA', zip: '31015',
      phone_number: '(229) 271-0055', latitude: 31.9723, longitude: -83.7601,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 14_000, uleage_90: 12_600, cutoff_percent: 10
    )
  },
  {
    customer: customers[6],
    location: Location.create!(
      company_name: 'BP – Americus',
      address: '700 S Lee St', city: 'Americus', state: 'GA', zip: '31709',
      phone_number: '(229) 924-8810', latitude: 32.0634, longitude: -84.2317,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 12_000, uleage_90: 10_800, cutoff_percent: 10
    )
  },
  {
    customer: customers[7],
    location: Location.create!(
      company_name: "Love's Travel Stop #542",
      address: '120 Love\'s Way', city: 'Unadilla', state: 'GA', zip: '31091',
      phone_number: '(229) 924-0040', latitude: 32.2593, longitude: -83.7355,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 30_000, uleage_90: 27_000, cutoff_percent: 10,
      notes: 'Large semi truck stop – call ahead 2 hrs. Use rear fueling lane.'
    )
  },
  {
    customer: nil,
    location: Location.create!(
      company_name: 'Circle K – Fitzgerald',
      address: '308 W Pine St', city: 'Fitzgerald', state: 'GA', zip: '31750',
      phone_number: '(229) 423-5500', latitude: 31.7193, longitude: -83.2549,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 15_000, uleage_90: 13_500, cutoff_percent: 10
    )
  },
  {
    customer: nil,
    location: Location.create!(
      company_name: 'Raceway – Moultrie',
      address: '1110 1st Ave SE', city: 'Moultrie', state: 'GA', zip: '31768',
      phone_number: '(229) 890-3210', latitude: 31.1699, longitude: -83.7714,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 16_000, uleage_90: 14_400, cutoff_percent: 10
    )
  }
]

# Link customers → locations
dest_locations.each do |dl|
  next if dl[:customer].nil?

  CustomerLocation.create!(customer: dl[:customer], location: dl[:location])
end

# Customers can have several locations, and a location can be shared by
# customers (the order form lists the customer's own locations first).
stuckeys_yard = Location.create!(company_name: "Stuckey's Fleet Yard", address: '1210 E Forsyth St', city: 'Americus',
                                 state: 'GA', zip: '31709', location_category: destination_cat)
shared_island = Location.create!(company_name: 'Sumter County Fuel Island', address: '400 Industrial Blvd', city: 'Americus',
                                 state: 'GA', zip: '31719', location_category: destination_cat)
CustomerLocation.create!(customer: customers[0], location: stuckeys_yard)
CustomerLocation.create!(customer: customers[0], location: shared_island)  # Stuckey's
CustomerLocation.create!(customer: customers[6], location: shared_island)  # BP – Americus

# Add location contacts
LocationContact.create!(location_id: dest_locations[0][:location].id, name: 'Bobby Haynes', phone: '(229) 924-3300',
                        email: 'bhaynes@stuckeys.com')
LocationContact.create!(location_id: dest_locations[1][:location].id, name: 'Sandra Odom', phone: '(229) 883-1200',
                        email: 'sodom@qt.com')
LocationContact.create!(location_id: dest_locations[4][:location].id, name: 'Mike Caruthers', phone: '(229) 386-7700',
                        email: 'mcaruthers@parkers.com')
LocationContact.create!(location_id: dest_locations[7][:location].id, name: 'Dawn Merritt', phone: '(229) 924-0040',
                        email: 'dmerritt@loves.com')

# Assign products to destination locations
dest_locations.each do |dl|
  loc = dl[:location]
  LocationProduct.create!(location: loc, product: products[:regular], max_capacity: 8000,  uleage_90: 7200, cutoff: 10)
  LocationProduct.create!(location: loc, product: products[:plus],    max_capacity: 4000,  uleage_90: 3600, cutoff: 10)
  LocationProduct.create!(location: loc, product: products[:uls],     max_capacity: 6000,  uleage_90: 5400, cutoff: 10)
  next unless [
    0, 4, 7
  ].include?(dest_locations.index(dl))

  LocationProduct.create!(location: loc, product: products[:def_fluid], max_capacity: 2000, uleage_90: 1800,
                          cutoff: 10)
end

# ---------------------------------------------------------------------------
# CUSTOMER ORDERS
# ---------------------------------------------------------------------------
puts 'Seeding customer orders...'

today = Date.today

# Recent completed orders (past 30 days)
completed_orders = [
  CustomerOrder.create!(location: dest_locations[0][:location], customer: customers[0],
                        required_delivery_date: today - 18, order_status: 'Billed',
                        approximate_product_amount: 8000, notes: 'Delivered full load regular + ULS', card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[1][:location], customer: customers[1],
                        required_delivery_date: today - 14, order_status: 'Billed',
                        approximate_product_amount: 9000, notes: 'Split load – 5000 regular / 4000 plus', card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[4][:location], customer: customers[4],
                        required_delivery_date: today - 10, order_status: 'Billed',
                        approximate_product_amount: 7500, card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[7][:location], customer: customers[7],
                        required_delivery_date: today - 7, order_status: 'Billed',
                        approximate_product_amount: 12_000, notes: "Love's full tanker – all ULS", card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[2][:location], customer: customers[2],
                        required_delivery_date: today - 5, order_status: 'Billed',
                        approximate_product_amount: 6000, card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[5][:location], customer: customers[5],
                        required_delivery_date: today - 3, order_status: 'Billed',
                        approximate_product_amount: 5500, card_color: 'green')
]

# Active / new orders
active_orders = [
  CustomerOrder.create!(location: dest_locations[0][:location], customer: customers[0],
                        required_delivery_date: today + 1, order_status: 'Open Order',
                        approximate_product_amount: 8500, notes: 'Low on regular – priority delivery', card_color: 'yellow'),
  CustomerOrder.create!(location: dest_locations[1][:location], customer: customers[1],
                        required_delivery_date: today + 1, order_status: 'Open Order',
                        approximate_product_amount: 9000, card_color: 'yellow'),
  CustomerOrder.create!(location: dest_locations[3][:location], customer: customers[3],
                        required_delivery_date: today + 2, order_status: 'Open Order',
                        approximate_product_amount: 7000, notes: 'Flash Foods – confirm gate code with Sandra before arrival', card_color: 'blue'),
  CustomerOrder.create!(location: dest_locations[4][:location], customer: customers[4],
                        required_delivery_date: today + 2, order_status: 'Open Order',
                        approximate_product_amount: 9000, card_color: 'blue'),
  CustomerOrder.create!(location: dest_locations[6][:location], customer: customers[6],
                        required_delivery_date: today + 3, order_status: 'Open Order',
                        approximate_product_amount: 5000, card_color: 'blue'),
  CustomerOrder.create!(location: dest_locations[7][:location], customer: customers[7],
                        required_delivery_date: today + 3, order_status: 'Open Order',
                        approximate_product_amount: 14_000, notes: 'Large load – needs Trailer 201', card_color: 'blue'),
  CustomerOrder.create!(location: dest_locations[8][:location], customer: nil,
                        required_delivery_date: today + 4, order_status: 'Open Order',
                        approximate_product_amount: 6500, card_color: 'white'),
  CustomerOrder.create!(location: dest_locations[9][:location], customer: nil,
                        required_delivery_date: today + 5, order_status: 'Open Order',
                        approximate_product_amount: 7500, card_color: 'white'),
  CustomerOrder.create!(location: dest_locations[2][:location], customer: customers[2],
                        required_delivery_date: today + 4, order_status: 'Pending',
                        approximate_product_amount: 4500, notes: 'Customer requested delay – tank maintenance', card_color: 'red')
]

# Add products to some orders
[active_orders[0], active_orders[1]].each do |order|
  CustomerOrderProduct.create!(customer_order: order, product: products[:regular], quantity: 5000, price: 3.189)
  CustomerOrderProduct.create!(customer_order: order, product: products[:plus],    quantity: 2000, price: 3.399)
  CustomerOrderProduct.create!(customer_order: order, product: products[:uls],     quantity: 1500, price: 3.789)
end

CustomerOrderProduct.create!(customer_order: active_orders[3], product: products[:regular], quantity: 6000,
                             price: 3.189)
CustomerOrderProduct.create!(customer_order: active_orders[3], product: products[:uls], quantity: 3000,
                             price: 3.789)

CustomerOrderProduct.create!(customer_order: active_orders[5], product: products[:uls], quantity: 14_000, price: 3.789)

# ---------------------------------------------------------------------------
# DISPATCHES
# ---------------------------------------------------------------------------
puts 'Seeding dispatches...'

# Billed / complete dispatches (history)
billed_dispatches = [
  Dispatch.create!(
    origin: origins[0].full_address_with_company,
    destination: dest_locations[0][:location].full_address_with_company,
    destination_location: dest_locations[0][:location],
    dispatch_date: today - 18, status: 'Billed',
    driver: drivers[0], truck: trucks[0], trailer: trailers[0],
    vendor: vendors[0], info: 'Full load – 8000 gal regular',
    notes: 'Delivered on time. No issues.'
  ),
  Dispatch.create!(
    origin: origins[0].full_address_with_company,
    destination: dest_locations[1][:location].full_address_with_company,
    destination_location: dest_locations[1][:location],
    dispatch_date: today - 14, status: 'Billed',
    driver: drivers[1], truck: trucks[1], trailer: trailers[1],
    vendor: vendors[0], info: '9000 gal split – regular/plus',
    notes: 'Customer requested split compartments.'
  ),
  Dispatch.create!(
    origin: origins[1].full_address_with_company,
    destination: dest_locations[4][:location].full_address_with_company,
    destination_location: dest_locations[4][:location],
    dispatch_date: today - 10, status: 'Billed',
    driver: drivers[2], truck: trucks[2], trailer: trailers[0],
    vendor: vendors[2], info: '7500 gal ULS',
    notes: 'Delivered to rear bay as requested.'
  ),
  Dispatch.create!(
    origin: origins[0].full_address_with_company,
    destination: dest_locations[7][:location].full_address_with_company,
    destination_location: dest_locations[7][:location],
    dispatch_date: today - 7, status: 'Billed',
    driver: drivers[0], truck: trucks[0], trailer: trailers[2],
    vendor: vendors[0], info: '12000 gal ULS – Love\'s full load'
  ),
  Dispatch.create!(
    origin: origins[2].full_address_with_company,
    destination: dest_locations[2][:location].full_address_with_company,
    destination_location: dest_locations[2][:location],
    dispatch_date: today - 5, status: 'Complete',
    driver: drivers[3], truck: trucks[3], trailer: trailers[1],
    vendor: vendors[3], info: '6000 gal regular'
  ),
  Dispatch.create!(
    origin: origins[1].full_address_with_company,
    destination: dest_locations[5][:location].full_address_with_company,
    destination_location: dest_locations[5][:location],
    dispatch_date: today - 3, status: 'Complete',
    driver: drivers[4], truck: trucks[4], trailer: trailers[3],
    vendor: vendors[2], info: '5500 gal – regular/ULS split'
  )
]

billed_dispatches.zip(completed_orders).each do |dispatch, order|
  DispatchCustomerOrder.create!(dispatch: dispatch, customer_order: order)
end

# Today's dispatches (sent to driver / in progress)
todays_dispatches = [
  Dispatch.create!(
    origin: origins[0].full_address_with_company,
    destination: dest_locations[0][:location].full_address_with_company,
    destination_location: dest_locations[0][:location],
    dispatch_date: today, status: 'Sent to Driver',
    driver: drivers[0], truck: trucks[0], trailer: trailers[0],
    vendor: vendors[0], info: '8500 gal – priority delivery',
    notes: 'Depart by 6:00 AM. Low tank alert from customer.'
  ),
  Dispatch.create!(
    origin: origins[0].full_address_with_company,
    destination: dest_locations[1][:location].full_address_with_company,
    destination_location: dest_locations[1][:location],
    dispatch_date: today, status: 'Sent to Driver',
    driver: drivers[1], truck: trucks[1], trailer: trailers[1],
    vendor: vendors[0], info: '9000 gal regular + plus',
    notes: 'See BOL #44821 attached.'
  ),
  Dispatch.create!(
    origin: origins[1].full_address_with_company,
    destination: dest_locations[3][:location].full_address_with_company,
    destination_location: dest_locations[3][:location],
    dispatch_date: today, status: 'New',
    driver: drivers[2], truck: trucks[2], trailer: trailers[2],
    vendor: vendors[2], info: '7000 gal',
    notes: 'Gate code: 4481. Ask for Sandra.'
  )
]

DispatchCustomerOrder.create!(dispatch: todays_dispatches[0], customer_order: active_orders[0])
DispatchCustomerOrder.create!(dispatch: todays_dispatches[1], customer_order: active_orders[1])
DispatchCustomerOrder.create!(dispatch: todays_dispatches[2], customer_order: active_orders[2])

# Upcoming dispatches (new / scheduled)
upcoming_dispatches = [
  Dispatch.create!(
    origin: origins[0].full_address_with_company,
    destination: dest_locations[4][:location].full_address_with_company,
    destination_location: dest_locations[4][:location],
    dispatch_date: today + 1, status: 'New',
    driver: drivers[3], truck: trucks[3], trailer: trailers[0],
    vendor: vendors[0], info: '9000 gal regular + ULS'
  ),
  Dispatch.create!(
    origin: origins[2].full_address_with_company,
    destination: dest_locations[6][:location].full_address_with_company,
    destination_location: dest_locations[6][:location],
    dispatch_date: today + 1, status: 'New',
    driver: drivers[4], truck: trucks[4], trailer: trailers[3],
    vendor: vendors[3], info: '5000 gal regular'
  ),
  Dispatch.create!(
    origin: origins[0].full_address_with_company,
    destination: dest_locations[7][:location].full_address_with_company,
    destination_location: dest_locations[7][:location],
    dispatch_date: today + 2, status: 'New',
    driver: drivers[0], truck: trucks[0], trailer: trailers[2],
    vendor: vendors[0], info: '14000 gal ULS – large load',
    notes: "Love's 542 – call Dawn Merritt 2 hrs before arrival."
  ),
  Dispatch.create!(
    origin: origins[1].full_address_with_company,
    destination: dest_locations[8][:location].full_address_with_company,
    destination_location: dest_locations[8][:location],
    dispatch_date: today + 3, status: 'New',
    driver: drivers[1], truck: trucks[1], trailer: trailers[1],
    vendor: vendors[2], info: '6500 gal regular'
  ),
  Dispatch.create!(
    origin: origins[1].full_address_with_company,
    destination: dest_locations[9][:location].full_address_with_company,
    destination_location: dest_locations[9][:location],
    dispatch_date: today + 4, status: 'New',
    driver: drivers[2], truck: trucks[2], trailer: trailers[0],
    vendor: vendors[2], info: '7500 gal – regular/plus'
  )
]

DispatchCustomerOrder.create!(dispatch: upcoming_dispatches[0], customer_order: active_orders[3])
DispatchCustomerOrder.create!(dispatch: upcoming_dispatches[1], customer_order: active_orders[4])
DispatchCustomerOrder.create!(dispatch: upcoming_dispatches[2], customer_order: active_orders[5])

# ---------------------------------------------------------------------------
# DISPATCH MESSAGES
# ---------------------------------------------------------------------------
puts 'Seeding dispatch messages...'

DispatchMessage.create!(
  dispatch: todays_dispatches[0], user: admin,
  message_body: "Ray – priority run to Stuckey's this morning. They're critically low. Depart ASAP.",
  delivery_method: 'sms', sent_at: Time.now - 2.hours, status: 'delivered'
)
DispatchMessage.create!(
  dispatch: todays_dispatches[0], user: drivers[0],
  message_body: 'Loaded and rolling. ETA 7:45 AM.',
  delivery_method: 'sms', sent_at: Time.now - 1.5.hours, status: 'delivered'
)
DispatchMessage.create!(
  dispatch: todays_dispatches[1], user: dispatcher_user,
  message_body: 'Tony – BOL attached. QT wants the regular in compartment 1, plus in compartment 2.',
  delivery_method: 'sms', sent_at: Time.now - 1.hour, status: 'delivered'
)
DispatchMessage.create!(
  dispatch: billed_dispatches[3], user: drivers[0],
  message_body: "Delivered Love's 542. Signed off by Dawn. 12,000 gal.",
  delivery_method: 'sms', sent_at: (today - 7).to_time + 14.hours, status: 'delivered'
)

# ---------------------------------------------------------------------------
# PRODUCTION ORDERS
# ---------------------------------------------------------------------------
puts 'Seeding production orders...'

# Completed production orders
ProductionOrder.create!(
  item: 'Regular Unleaded – 87 Oct Blend',
  product: products[:regular],
  customer: customers[0], location: dest_locations[0][:location],
  qty_to_make: 10_000.000, total_qty_produced: 10_000.000,
  status: 'completed',
  due_date: today - 12, production_date: today - 13,
  date_started: today - 14, date_completed: today - 13,
  filled_by: 'Ray Brown', approved_by: 'John Perry',
  batch_number: 'B-2026-0041',
  production_notes: 'Blended at Albany terminal. Met spec. Density check passed.'
)

ProductionOrder.create!(
  item: 'Ultra Low Sulfur Diesel',
  product: products[:uls],
  customer: customers[7], location: dest_locations[7][:location],
  qty_to_make: 12_000.000, total_qty_produced: 12_000.000,
  status: 'completed',
  due_date: today - 6, production_date: today - 7,
  date_started: today - 7, date_completed: today - 7,
  filled_by: 'Marcus Thomas', approved_by: 'John Perry',
  batch_number: 'B-2026-0042',
  production_notes: "Full load for Love's 542. Sulfur content verified < 15 ppm."
)

ProductionOrder.create!(
  item: 'Dyed ULS Diesel – Farm Tax Exempt',
  product: products[:dyed_uls],
  customer: customers[4], location: dest_locations[4][:location],
  qty_to_make: 3000.000, total_qty_produced: 3000.000,
  status: 'completed',
  due_date: today - 9, production_date: today - 10,
  date_started: today - 10, date_completed: today - 10,
  filled_by: 'Tony Williams', approved_by: 'Lisa Hargrove',
  batch_number: 'B-2026-0040',
  production_notes: 'Red dye added per IRS tax-exempt requirements. Visual confirmation per batch log.'
)

# In-progress production orders
po_in_progress_1 = ProductionOrder.create!(
  item: 'Regular Unleaded – 87 Oct Blend',
  product: products[:regular],
  customer: customers[1], location: dest_locations[1][:location],
  qty_to_make: 9000.000, total_qty_produced: 4500.000,
  status: 'in_progress',
  due_date: today + 1, production_date: today,
  date_started: today,
  filled_by: 'Ray Brown',
  batch_number: 'B-2026-0043',
  production_notes: 'First half loaded. Second pull scheduled this afternoon.'
)

ProductionOrder.create!(
  item: 'DEF – Diesel Exhaust Fluid',
  product: products[:def_fluid],
  customer: customers[7], location: dest_locations[7][:location],
  qty_to_make: 2000.000,
  status: 'in_progress',
  due_date: today + 2, production_date: today + 1,
  date_started: today,
  filled_by: 'Kevin Moore',
  batch_number: 'B-2026-0044',
  production_notes: 'ISO 22241 compliance required. QC sample pulled.'
)

# Created (not started) production orders
ProductionOrder.create!(
  item: 'Plus Midgrade – 89 Oct',
  product: products[:plus],
  customer: customers[0], location: dest_locations[0][:location],
  qty_to_make: 4000.000,
  status: 'created',
  due_date: today + 3, production_date: today + 2,
  notes: 'Customer requests early morning delivery window 6–8 AM.'
)

ProductionOrder.create!(
  item: 'Ultra Low Sulfur Diesel',
  product: products[:uls],
  customer: customers[7], location: dest_locations[7][:location],
  qty_to_make: 14_000.000,
  status: 'created',
  due_date: today + 3,
  notes: "Large run for Love's 542. Coordinate with dispatch for Trailer 201."
)

ProductionOrder.create!(
  item: 'Reg-E10 Ethanol Blend',
  product: products[:reg_e10],
  customer: customers[3], location: dest_locations[3][:location],
  qty_to_make: 7000.000,
  status: 'created',
  due_date: today + 4,
  notes: 'Verify ethanol blend ratio before loading. Target 10% ethanol.'
)

ProductionOrder.create!(
  item: 'Dyed ULS Diesel – Farm Tax Exempt',
  product: products[:dyed_uls],
  qty_to_make: 5000.000,
  status: 'created',
  due_date: today + 6,
  notes: 'Spec order – no customer assigned yet. Hold at terminal pending confirmation.'
)

ProductionOrder.create!(
  item: 'Regular Unleaded – 87 Oct Blend',
  product: products[:regular],
  customer: customers[2], location: dest_locations[2][:location],
  qty_to_make: 6000.000,
  status: 'created',
  due_date: today + 5,
  notes: 'Murphy Express Albany – routine order.'
)

# Add batches to completed production orders
prod_complete_1 = ProductionOrder.where(status: 'completed').first
ProductionOrderBatch.create!(production_order: prod_complete_1, batch_number: 'B-2026-0041-A', quantity: 5000.000)
ProductionOrderBatch.create!(production_order: prod_complete_1, batch_number: 'B-2026-0041-B', quantity: 5000.000)

ProductionOrderBatch.create!(production_order: po_in_progress_1, batch_number: 'B-2026-0043-A', quantity: 4500.000)

# ---------------------------------------------------------------------------
# WORK ORDERS
# ---------------------------------------------------------------------------
puts 'Seeding work orders...'

WorkOrder.create!(
  workable: trucks[0],
  subject: 'Oil Change & DOT Inspection – Truck 101',
  description: 'Scheduled 50,000-mile service. Oil change, filter, tire rotation, lights check.',
  status: 'complete',
  assigned_to: drivers[0].id,
  vendor_id: vendors[0].id
)

WorkOrder.create!(
  workable: trailers[2],
  subject: 'Trailer Valve Leak – Trailer 203',
  description: 'Driver reported slow drip from valve 3 on Trailer 203 after last run. Taken out of service pending repair.',
  status: 'open',
  assigned_to: admin.id,
  vendor_id: vendors[1].id
)

WorkOrder.create!(
  workable: dest_locations[7][:location],
  subject: "Love's 542 – Fueling Lane Repaving",
  description: "Customer reported crack in rear fueling lane asphalt causing drainage issue. Coordinating with Love's facilities team.",
  status: 'open',
  assigned_to: dispatcher_user.id
)

WorkOrder.create!(
  workable: trucks[1],
  subject: 'Brake Adjustment – Truck 102',
  description: 'Air brake adjustment needed after pre-trip inspection flagged adjustment on rear axle.',
  status: 'in_progress',
  assigned_to: admin.id,
  vendor_id: vendors[1].id
)

# ---------------------------------------------------------------------------
# ANNOUNCEMENTS
# ---------------------------------------------------------------------------
puts 'Seeding announcements...'

Announcement.create!(
  title: 'Holiday Schedule – Memorial Day',
  content: 'Office and dispatch will operate on reduced hours Memorial Day weekend (Sat–Mon). Emergency deliveries contact John at (229) 924-1100.',
  status: 'active',
  published_at: today - 2
)

Announcement.create!(
  title: 'New BOL Procedure – Effective Immediately',
  content: 'All drivers must photograph and upload BOL via the dispatch portal before leaving the delivery site. Paper copies still required but portal upload is now mandatory.',
  status: 'active',
  published_at: today - 5
)

Announcement.create!(
  title: 'Trailer 203 Out of Service',
  content: 'Trailer 203 is out of service pending valve repair. Do not assign to loads until work order is closed.',
  status: 'active',
  published_at: today
)

# ---------------------------------------------------------------------------
# PRICING — costs, BOMs, pricing rules, and price-locking quotes
# Covers every pricing case: all three cost bases, back-/future-dated standard
# costs, a BOM with a component missing its standard cost, a customer-specific
# rule, and quotes in each lock state (active, being replaced, scheduled,
# expired, sent, draft, rejected, legacy).
# ---------------------------------------------------------------------------
puts 'Seeding pricing...'

def std_cost(product, amount, effective_date, user)
  product.standard_cost_histories.create!(amount: amount, effective_date: effective_date, created_by: user)
end

# Inventory (weighted average) cost and standard cost on the fuels.
# Standard cost is set a month back, so it differs from inventory cost.
{
  regular: [2.412, 2.380], plus: [2.598, 2.560], super_fuel: [2.771, 2.740],
  uls: [2.905, 2.860], dyed_uls: [2.845, 2.800], reg_e10: [2.398, 2.370], eth_regular: [2.405, 2.375]
}.each do |key, (inventory_cost, standard)|
  products[key].update!(cost_per_unit: inventory_cost, is_raw_material: false)
  std_cost(products[key], standard, today - 30, admin)
  products[key].update_column(:standard_cost, standard)
end

# ULS: an older back-dated entry (ignored — superseded) and a future increase
# (ignored until its date). Current standard cost stays 2.860.
std_cost(products[:uls], 2.700, today - 90, admin)
std_cost(products[:uls], 3.050, today + 14, admin)

# DEF raw materials. The label has NO standard cost on purpose, so the
# 2.5 gal jug's BOM cost can't be calculated (shows the missing-component alert).
raw = {
  urea: Product.create!(id: 'UREA001', name: 'Urea (prilled)', unit_of_measurement: 'lb', is_raw_material: true,
                        cost_per_unit: 0.335, current_stock: 42_000, reorder_point: 15_000),
  water: Product.create!(id: 'DIW001', name: 'Deionized Water', unit_of_measurement: 'gal', is_raw_material: true,
                         cost_per_unit: 0.021, current_stock: 9_000, reorder_point: 2_000),
  jug: Product.create!(id: 'JUG25', name: 'Jug, 2.5 gal', unit_of_measurement: 'ea', is_raw_material: true,
                       cost_per_unit: 0.880, current_stock: 1_200, reorder_point: 400),
  label: Product.create!(id: 'LBL25', name: 'Label, DEF 2.5 gal', unit_of_measurement: 'ea', is_raw_material: true,
                         cost_per_unit: 0.060, current_stock: 3_000, reorder_point: 500),
  tote: Product.create!(id: 'TOTE275', name: 'IBC Tote, 275 gal', unit_of_measurement: 'ea', is_raw_material: true,
                        cost_per_unit: 182.00, current_stock: 24, reorder_point: 10)
}
std_cost(raw[:urea],  0.320, today - 45, admin)
std_cost(raw[:water], 0.020, today - 45, admin)
std_cost(raw[:jug],   0.850, today - 45, admin)
std_cost(raw[:tote],  175.00, today - 45, admin)
raw.each_value { |p| p.update_column(:standard_cost, p.current_standard_cost) }

# DEF is 32.5% urea: ~2.95 lb urea + ~0.73 gal DI water per gallon.
def_bulk = products[:def_fluid]
def_bulk.update!(cost_per_unit: 1.18, is_raw_material: false)
ProductComponent.create!(product: def_bulk, component_product: raw[:urea],  quantity_per_unit: 2.95, uom: 'lb')
ProductComponent.create!(product: def_bulk, component_product: raw[:water], quantity_per_unit: 0.73, uom: 'gal')
std_cost(def_bulk, 1.00, today - 45, admin)
def_bulk.update_column(:standard_cost, 1.00)

def_jug = Product.create!(id: 'DEF25', name: 'DEF 2.5 Gal Jug', unit_of_measurement: 'ea', weight: 22.7,
                          is_raw_material: false, cost_per_unit: 4.10)
ProductComponent.create!(product: def_jug, component_product: def_bulk,    quantity_per_unit: 2.5, uom: 'gal')
ProductComponent.create!(product: def_jug, component_product: raw[:jug],   quantity_per_unit: 1,   uom: 'ea')
ProductComponent.create!(product: def_jug, component_product: raw[:label], quantity_per_unit: 1,   uom: 'ea')

def_tote = Product.create!(id: 'DEF275', name: 'DEF 275 Gal Tote', unit_of_measurement: 'ea', weight: 2497,
                           is_raw_material: false, cost_per_unit: 498.00)
ProductComponent.create!(product: def_tote, component_product: def_bulk,   quantity_per_unit: 275, uom: 'gal')
ProductComponent.create!(product: def_tote, component_product: raw[:tote], quantity_per_unit: 1,   uom: 'ea')

def pricing_rule(name, basis, method, value, products, customer: nil, effective_date: nil, expiration_date: nil)
  rule = PricingRule.create!(name: name, pricing_basis: basis, pricing_method: method, value: value,
                             customer: customer, effective_date: effective_date, expiration_date: expiration_date)
  rule.products << products
  rule
end

fuels = products.values_at(:regular, :plus, :super_fuel, :uls, :dyed_uls, :reg_e10, :eth_regular)
rules = {
  fuel: pricing_rule('Fuel – Rack + 8%', 'inventory_cost', 'markup', 8, fuels),
  def_bulk: pricing_rule('DEF Bulk – Std Cost + 25%',   'standard_cost',       'markup', 25, [def_bulk]),
  def_pack: pricing_rule('DEF Packaged – BOM @ 30% GM', 'standard_calculated', 'margin', 30, [def_jug, def_tote]),
  loves_dsl: pricing_rule("Love's Diesel – 5% GM", 'inventory_cost', 'margin', 5,
                          products.values_at(:uls, :dyed_uls), customer: customers[7]),
  summer: pricing_rule('Summer Promo (expired)', 'inventory_cost', 'markup', 4, [products[:regular]],
                       effective_date: today - 120, expiration_date: today - 30)
}

# Quotes are created through the models so each line gets its pricing snapshot.
def seed_quote(customer:, lines:, status: 'draft', valid_from: Date.today, valid_until: Date.today.end_of_month,
               locks_pricing: true, notes: nil, accept_as: nil, sent_at: nil)
  quote = Quote.create!(
    customer: customer, location: customer.locations.first, locks_pricing: locks_pricing,
    valid_from: valid_from, expiry_date: valid_until, notes: notes, sent_at: sent_at,
    quote_products_attributes: lines.map do |product, qty, rule, price|
      price ||= rule&.calculated_price(product)
      { product_id: product.id, quantity: qty, price: price, pricing_rule_id: rule&.id }
    end
  )
  quote.update!(status: 'sent', sent_at: sent_at || (2.days.ago)) if %w[sent accepted
                                                                        rejected].include?(status)
  quote.accept!(accept_as) if status == 'accepted'
  quote.update!(status: 'rejected') if status == 'rejected'
  quote
end

stuckeys, qt, murphy, flash, parkers, sunoco, bp, loves = customers

# Stuckey's: older lock on diesel + DEF, being replaced by a newer quote in 5 days.
stuckeys_old = seed_quote(customer: stuckeys, status: 'accepted', accept_as: admin,
                          valid_from: today - 20, valid_until: today + 40, notes: 'Q3 fleet diesel agreement',
                          lines: [[products[:uls], 8000, rules[:fuel]], [def_bulk, 1200, rules[:def_bulk]], [def_tote, 4, rules[:def_pack]]])
seed_quote(customer: stuckeys, status: 'accepted', accept_as: admin,
           valid_from: today + 5, valid_until: (today + 5).end_of_quarter, notes: 'Q4 diesel — renegotiated',
           lines: [[products[:uls], 9000, rules[:fuel], 3.0950]]) # hand-negotiated below rule price → overridden

# Quick Trip: active lock through month end on gasoline (one line overridden by hand).
qt_quote = seed_quote(customer: qt, status: 'accepted', accept_as: admin,
                      valid_from: today.beginning_of_month, valid_until: today.end_of_month,
                      lines: [[products[:regular], 6000, rules[:fuel]], [products[:plus], 2500, rules[:fuel], 2.7500],
                              [products[:super_fuel], 1500, rules[:fuel]]])

# Love's: lock built from their customer-specific diesel rule, 90 days.
seed_quote(customer: loves, status: 'accepted', accept_as: admin,
           valid_from: today - 10, valid_until: today + 79, notes: '90-day diesel price hold',
           lines: [[products[:uls], 14_000, rules[:loves_dsl]], [products[:dyed_uls], 4000, rules[:loves_dsl]]])

# Murphy: accepted, but the lock starts next month (scheduled).
seed_quote(customer: murphy, status: 'accepted', accept_as: admin,
           valid_from: today.next_month.beginning_of_month, valid_until: today.next_month.end_of_month,
           lines: [[products[:regular], 7500, rules[:fuel]], [products[:reg_e10], 3000, rules[:fuel]]])

# Flash Foods: lock that expired last quarter.
seed_quote(customer: flash, status: 'accepted', accept_as: admin,
           valid_from: today.prev_quarter.beginning_of_quarter, valid_until: today.prev_quarter.end_of_quarter,
           lines: [[products[:regular], 5000, rules[:fuel], 2.4900]])

# Parker's: sent, awaiting the customer (includes DEF jugs — BOM can't price, so manual price).
seed_quote(customer: parkers, status: 'sent', valid_until: today + 29,
           lines: [[def_bulk, 600, rules[:def_bulk]], [def_jug, 120, nil, 9.95]])

# Sunoco: draft in progress. BP: rejected.
seed_quote(customer: sunoco, status: 'draft',
           lines: [[products[:regular], 4000, rules[:fuel]], [products[:eth_regular], 2000, rules[:fuel]]])
seed_quote(customer: bp, status: 'rejected', valid_from: today - 15, valid_until: today + 15,
           lines: [[products[:uls], 3000, rules[:fuel], 2.9000]])

# Legacy quote from before price locking (product name only, never locks).
legacy = Quote.create!(customer: qt, status: 'accepted', expiry_date: today - 60, notes: 'Created before price locking',
                       quote_products_attributes: [{ product_name: 'Regular', quantity: 5000, price: 3.10 }])
legacy.update_columns(created_at: today - 90)

# Costs moved after the quotes were locked — this is what the Quote Margin
# Review compares. Lines count as priced on their quote's start date.
QuoteProduct.joins(:quote).merge(Quote.accepted_locks).find_each do |qp|
  qp.update_column(:priced_at, [qp.quote.valid_from, today].min.to_time)
end
std_cost(def_bulk, 1.12, today - 3, admin)        # DEF bulk standard cost +12%
def_bulk.update_column(:standard_cost, 1.12)
std_cost(raw[:urea], 0.36, today - 6, admin)      # urea +12.5% → flows into DEF tote BOM cost
raw[:urea].update_column(:standard_cost, 0.36)
products[:uls].update!(cost_per_unit: 3.020)      # inventory cost changes are recorded in history
products[:dyed_uls].update!(cost_per_unit: 2.955)
products[:regular].update!(cost_per_unit: 2.431)

# Orders priced from a lock and from a rule, so the audit trail has something to show.
stuckeys_uls = stuckeys_old.quote_products.find_by(product_id: products[:uls].id)
locked_order = CustomerOrder.create!(customer: stuckeys, location: stuckeys.locations.first || dest_locations.first,
                                     order_status: 'Open Order', required_delivery_date: today + 2,
                                     notes: "Created from Quote #{stuckeys_old.quote_number}")
CustomerOrderProduct.create!(customer_order: locked_order, product: products[:uls], quantity: 7500,
                             price: stuckeys_uls.price, quote_product: stuckeys_uls)

qt_regular = qt_quote.quote_products.find_by(product_id: products[:regular].id)
qt_order = CustomerOrder.create!(customer: qt, location: qt.locations.first || dest_locations.first,
                                 order_status: 'Open Order', required_delivery_date: today + 3)
CustomerOrderProduct.create!(customer_order: qt_order, product: products[:regular], quantity: 6000,
                             price: qt_regular.price, quote_product: qt_regular)
CustomerOrderProduct.create!(customer_order: qt_order, product: products[:uls], quantity: 2000,
                             price: rules[:fuel].calculated_price(products[:uls]), pricing_rule: rules[:fuel])

puts ''
puts '✓ Seed complete!'
puts "  #{User.count} users (#{User.where(role: 'worker').count} drivers)"
puts "  #{Customer.count} customers"
puts "  #{Location.count} locations (#{Location.where(location_category: origin_cat).count} origins, #{Location.where(location_category: destination_cat).count} destinations)"
puts "  #{Product.count} products"
puts "  #{Thing.count} fleet (#{Thing.where(category: 'truck').count} trucks, #{Thing.where(category: 'trailer').count} trailers)"
puts "  #{CustomerOrder.count} customer orders"
puts "  #{Dispatch.count} dispatches"
puts "  #{ProductionOrder.count} production orders"
puts "  #{WorkOrder.count} work orders"
puts "  #{PricingRule.count} pricing rules, #{Quote.count} quotes (#{Quote.accepted_locks.count} price locks)"
puts ''
puts '  Admin login: admin@perrybrothersoil.com / password123'
