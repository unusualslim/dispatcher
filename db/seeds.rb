# Perry Brothers Oil — Realistic Seed Data
# Americus / Albany, Georgia fuel delivery operation
#
# WARNING: This seed file destroys all existing data.
# It is intended for local development only and will NEVER run in production.

if Rails.env.production?
  puts "Skipping seeds in production environment."
  return
end

puts "Clearing existing data..."
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
Product.destroy_all
Thing.destroy_all
Vendor.destroy_all
Announcement.destroy_all
User.destroy_all

puts "Seeding location categories..."
origin_cat      = LocationCategory.create!(name: 'Origin')
destination_cat = LocationCategory.create!(name: 'Destination')

# ---------------------------------------------------------------------------
# PRODUCTS
# ---------------------------------------------------------------------------
puts "Seeding products..."
products = {
  regular:     Product.create!(id: 'REG001',  name: 'Regular',      unit_of_measurement: 'gallons', weight: 6.073),
  plus:        Product.create!(id: 'PLUS001', name: 'Plus',          unit_of_measurement: 'gallons', weight: 6.073),
  super_fuel:  Product.create!(id: 'SUP001',  name: 'Super',         unit_of_measurement: 'gallons', weight: 6.073),
  def_fluid:   Product.create!(id: 'DEF001',  name: 'DEF',           unit_of_measurement: 'gallons', weight: 9.08),
  uls:         Product.create!(id: 'ULS001',  name: 'ULS',           unit_of_measurement: 'gallons', weight: 7.05),
  dyed_uls:    Product.create!(id: 'DULS001', name: 'Dyed ULS',      unit_of_measurement: 'gallons', weight: 7.05),
  reg_e10:     Product.create!(id: 'E10001',  name: 'Reg-E10',       unit_of_measurement: 'gallons', weight: 6.10),
  eth_regular: Product.create!(id: 'ETH001',  name: 'Eth-Regular',   unit_of_measurement: 'gallons', weight: 6.10),
}

# ---------------------------------------------------------------------------
# VENDORS
# ---------------------------------------------------------------------------
puts "Seeding vendors..."
vendors = [
  Vendor.create!(name: 'Mansfield Oil Company'),
  Vendor.create!(name: 'Pilot Flying J Supply'),
  Vendor.create!(name: 'Hunt Refining Co.'),
  Vendor.create!(name: 'Gulf Oil Partners'),
]

# ---------------------------------------------------------------------------
# TRUCKS & TRAILERS (Things)
# ---------------------------------------------------------------------------
puts "Seeding fleet..."
trucks = [
  Thing.create!(name: 'Truck 101 – Kenworth T680',   category: 'truck'),
  Thing.create!(name: 'Truck 102 – Peterbilt 389',   category: 'truck'),
  Thing.create!(name: 'Truck 103 – Freightliner Cascadia', category: 'truck'),
  Thing.create!(name: 'Truck 104 – Kenworth W900',   category: 'truck'),
  Thing.create!(name: 'Truck 105 – International LT', category: 'truck'),
]

trailers = [
  Thing.create!(name: 'Trailer 201 – 9000 gal Tanker',  category: 'trailer'),
  Thing.create!(name: 'Trailer 202 – 7500 gal Tanker',  category: 'trailer'),
  Thing.create!(name: 'Trailer 203 – 9000 gal Tanker',  category: 'trailer'),
  Thing.create!(name: 'Trailer 204 – 6000 gal Tanker',  category: 'trailer'),
]

# ---------------------------------------------------------------------------
# USERS
# ---------------------------------------------------------------------------
puts "Seeding users..."
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
    first_name: 'Ray',    last_name: 'Brown',
    phone_number: '(229) 555-0201', role: 'worker',
    sms_opt_in: true, email_opt_in: false
  ),
  User.create!(
    email: 'twilliams@perrybrothersoil.com',
    password: 'password123', password_confirmation: 'password123',
    first_name: 'Tony',   last_name: 'Williams',
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
    first_name: 'Kevin',  last_name: 'Moore',
    phone_number: '(229) 555-0205', role: 'worker',
    sms_opt_in: true, email_opt_in: false
  ),
]

# ---------------------------------------------------------------------------
# ORIGIN LOCATIONS (fuel terminals / rack)
# ---------------------------------------------------------------------------
puts "Seeding origin locations..."
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
  ),
]

# ---------------------------------------------------------------------------
# CUSTOMERS
# ---------------------------------------------------------------------------
puts "Seeding customers..."
customers = [
  Customer.create!(name: "Stuckey's Travel Center",    email: 'ops@stuckeys-americus.com',   phone: '(229) 924-3300', preferred_contact_method: 'phone'),
  Customer.create!(name: 'Quick Trip #4481',            email: 'manager4481@qt.com',           phone: '(229) 883-1200', preferred_contact_method: 'email'),
  Customer.create!(name: 'Murphy Express – Albany',     email: 'albany.ops@murphyusa.com',     phone: '(229) 430-5800', preferred_contact_method: 'phone'),
  Customer.create!(name: 'Flash Foods #228',            email: 'store228@flashfoods.com',       phone: '(229) 468-2100', preferred_contact_method: 'email'),
  Customer.create!(name: 'Parker\'s Kitchen – Tifton',  email: 'tifton@parkerskitchen.com',    phone: '(229) 386-7700', preferred_contact_method: 'phone'),
  Customer.create!(name: 'Sunoco – Cordele',            email: 'cordele.sunoco@gmail.com',      phone: '(229) 271-0055', preferred_contact_method: 'no preference'),
  Customer.create!(name: 'BP – Americus',               email: 'bp.americus@gmail.com',         phone: '(229) 924-8810', preferred_contact_method: 'phone'),
  Customer.create!(name: 'Loves Travel Stop #542',      email: 'store542@loves.com',            phone: '(229) 924-0040', preferred_contact_method: 'email'),
]

# ---------------------------------------------------------------------------
# DESTINATION LOCATIONS (customer delivery sites)
# ---------------------------------------------------------------------------
puts "Seeding destination locations..."
dest_locations = [
  {
    customer: customers[0],
    location: Location.create!(
      company_name: "Stuckey's Travel Center",
      address: '1201 E Forsyth St', city: 'Americus', state: 'GA', zip: '31709',
      phone_number: '(229) 924-3300', latitude: 32.0724, longitude: -84.2158,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 20000, uleage_90: 18000, cutoff_percent: 10
    )
  },
  {
    customer: customers[1],
    location: Location.create!(
      company_name: 'QuikTrip #4481',
      address: '2814 Dawson Rd', city: 'Albany', state: 'GA', zip: '31707',
      phone_number: '(229) 883-1200', latitude: 31.5812, longitude: -84.1923,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 24000, uleage_90: 21600, cutoff_percent: 10
    )
  },
  {
    customer: customers[2],
    location: Location.create!(
      company_name: 'Murphy Express – Albany Walmart',
      address: '2601 Pointe North Blvd', city: 'Albany', state: 'GA', zip: '31721',
      phone_number: '(229) 430-5800', latitude: 31.6130, longitude: -84.2212,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 18000, uleage_90: 16200, cutoff_percent: 10
    )
  },
  {
    customer: customers[3],
    location: Location.create!(
      company_name: 'Flash Foods #228',
      address: '601 N Irwin Ave', city: 'Ocilla', state: 'GA', zip: '31774',
      phone_number: '(229) 468-2100', latitude: 31.5954, longitude: -83.2482,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 16000, uleage_90: 14400, cutoff_percent: 10
    )
  },
  {
    customer: customers[4],
    location: Location.create!(
      company_name: "Parker's Kitchen",
      address: '915 US-82 E', city: 'Tifton', state: 'GA', zip: '31794',
      phone_number: '(229) 386-7700', latitude: 31.4513, longitude: -83.4880,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 22000, uleage_90: 19800, cutoff_percent: 10
    )
  },
  {
    customer: customers[5],
    location: Location.create!(
      company_name: 'Sunoco – Cordele',
      address: '1405 E 16th Ave', city: 'Cordele', state: 'GA', zip: '31015',
      phone_number: '(229) 271-0055', latitude: 31.9723, longitude: -83.7601,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 14000, uleage_90: 12600, cutoff_percent: 10
    )
  },
  {
    customer: customers[6],
    location: Location.create!(
      company_name: 'BP – Americus',
      address: '700 S Lee St', city: 'Americus', state: 'GA', zip: '31709',
      phone_number: '(229) 924-8810', latitude: 32.0634, longitude: -84.2317,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 12000, uleage_90: 10800, cutoff_percent: 10
    )
  },
  {
    customer: customers[7],
    location: Location.create!(
      company_name: "Love's Travel Stop #542",
      address: '120 Love\'s Way', city: 'Unadilla', state: 'GA', zip: '31091',
      phone_number: '(229) 924-0040', latitude: 32.2593, longitude: -83.7355,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 30000, uleage_90: 27000, cutoff_percent: 10,
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
      max_capacity: 15000, uleage_90: 13500, cutoff_percent: 10
    )
  },
  {
    customer: nil,
    location: Location.create!(
      company_name: 'Raceway – Moultrie',
      address: '1110 1st Ave SE', city: 'Moultrie', state: 'GA', zip: '31768',
      phone_number: '(229) 890-3210', latitude: 31.1699, longitude: -83.7714,
      location_category: destination_cat, marker_color: 'red',
      max_capacity: 16000, uleage_90: 14400, cutoff_percent: 10
    )
  },
]

# Link customers → locations
dest_locations.each do |dl|
  next if dl[:customer].nil?
  CustomerLocation.create!(customer: dl[:customer], location: dl[:location])
end

# Add location contacts
LocationContact.create!(location_id: dest_locations[0][:location].id, name: 'Bobby Haynes',   phone: '(229) 924-3300', email: 'bhaynes@stuckeys.com')
LocationContact.create!(location_id: dest_locations[1][:location].id, name: 'Sandra Odom',    phone: '(229) 883-1200', email: 'sodom@qt.com')
LocationContact.create!(location_id: dest_locations[4][:location].id, name: 'Mike Caruthers', phone: '(229) 386-7700', email: 'mcaruthers@parkers.com')
LocationContact.create!(location_id: dest_locations[7][:location].id, name: 'Dawn Merritt',   phone: '(229) 924-0040', email: 'dmerritt@loves.com')

# Assign products to destination locations
dest_locations.each do |dl|
  loc = dl[:location]
  LocationProduct.create!(location: loc, product: products[:regular], max_capacity: 8000,  uleage_90: 7200, cutoff: 10)
  LocationProduct.create!(location: loc, product: products[:plus],    max_capacity: 4000,  uleage_90: 3600, cutoff: 10)
  LocationProduct.create!(location: loc, product: products[:uls],     max_capacity: 6000,  uleage_90: 5400, cutoff: 10)
  LocationProduct.create!(location: loc, product: products[:def_fluid], max_capacity: 2000, uleage_90: 1800, cutoff: 10) if [0,4,7].include?(dest_locations.index(dl))
end

# ---------------------------------------------------------------------------
# CUSTOMER ORDERS
# ---------------------------------------------------------------------------
puts "Seeding customer orders..."

today = Date.today
all_dest_locations = dest_locations.map { |dl| dl[:location] }

# Recent completed orders (past 30 days)
completed_orders = [
  CustomerOrder.create!(location: dest_locations[0][:location], customer: customers[0],
    required_delivery_date: today - 18, order_status: 'Complete',
    approximate_product_amount: 8000, notes: 'Delivered full load regular + ULS', card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[1][:location], customer: customers[1],
    required_delivery_date: today - 14, order_status: 'Complete',
    approximate_product_amount: 9000, notes: 'Split load – 5000 regular / 4000 plus', card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[4][:location], customer: customers[4],
    required_delivery_date: today - 10, order_status: 'Complete',
    approximate_product_amount: 7500, card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[7][:location], customer: customers[7],
    required_delivery_date: today - 7, order_status: 'Complete',
    approximate_product_amount: 12000, notes: "Love's full tanker – all ULS", card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[2][:location], customer: customers[2],
    required_delivery_date: today - 5, order_status: 'Complete',
    approximate_product_amount: 6000, card_color: 'green'),
  CustomerOrder.create!(location: dest_locations[5][:location], customer: customers[5],
    required_delivery_date: today - 3, order_status: 'Complete',
    approximate_product_amount: 5500, card_color: 'green'),
]

# Active / new orders
active_orders = [
  CustomerOrder.create!(location: dest_locations[0][:location], customer: customers[0],
    required_delivery_date: today + 1, order_status: 'New',
    approximate_product_amount: 8500, notes: 'Low on regular – priority delivery', card_color: 'yellow'),
  CustomerOrder.create!(location: dest_locations[1][:location], customer: customers[1],
    required_delivery_date: today + 1, order_status: 'New',
    approximate_product_amount: 9000, card_color: 'yellow'),
  CustomerOrder.create!(location: dest_locations[3][:location], customer: customers[3],
    required_delivery_date: today + 2, order_status: 'New',
    approximate_product_amount: 7000, notes: 'Flash Foods – confirm gate code with Sandra before arrival', card_color: 'blue'),
  CustomerOrder.create!(location: dest_locations[4][:location], customer: customers[4],
    required_delivery_date: today + 2, order_status: 'New',
    approximate_product_amount: 9000, card_color: 'blue'),
  CustomerOrder.create!(location: dest_locations[6][:location], customer: customers[6],
    required_delivery_date: today + 3, order_status: 'New',
    approximate_product_amount: 5000, card_color: 'blue'),
  CustomerOrder.create!(location: dest_locations[7][:location], customer: customers[7],
    required_delivery_date: today + 3, order_status: 'New',
    approximate_product_amount: 14000, notes: "Large load – needs Trailer 201", card_color: 'blue'),
  CustomerOrder.create!(location: dest_locations[8][:location], customer: nil,
    required_delivery_date: today + 4, order_status: 'New',
    approximate_product_amount: 6500, card_color: 'white'),
  CustomerOrder.create!(location: dest_locations[9][:location], customer: nil,
    required_delivery_date: today + 5, order_status: 'New',
    approximate_product_amount: 7500, card_color: 'white'),
  CustomerOrder.create!(location: dest_locations[2][:location], customer: customers[2],
    required_delivery_date: today + 4, order_status: 'On Hold',
    approximate_product_amount: 4500, notes: 'Customer requested delay – tank maintenance', card_color: 'red'),
]

# Add products to some orders
[active_orders[0], active_orders[1]].each do |order|
  CustomerOrderProduct.create!(customer_order: order, product: products[:regular], quantity: 5000, price: 3.189)
  CustomerOrderProduct.create!(customer_order: order, product: products[:plus],    quantity: 2000, price: 3.399)
  CustomerOrderProduct.create!(customer_order: order, product: products[:uls],     quantity: 1500, price: 3.789)
end

CustomerOrderProduct.create!(customer_order: active_orders[3], product: products[:regular], quantity: 6000, price: 3.189)
CustomerOrderProduct.create!(customer_order: active_orders[3], product: products[:uls],     quantity: 3000, price: 3.789)

CustomerOrderProduct.create!(customer_order: active_orders[5], product: products[:uls], quantity: 14000, price: 3.789)

# ---------------------------------------------------------------------------
# DISPATCHES
# ---------------------------------------------------------------------------
puts "Seeding dispatches..."

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
    vendor: vendors[0], info: '12000 gal ULS – Love\'s full load',
  ),
  Dispatch.create!(
    origin: origins[2].full_address_with_company,
    destination: dest_locations[2][:location].full_address_with_company,
    destination_location: dest_locations[2][:location],
    dispatch_date: today - 5, status: 'Complete',
    driver: drivers[3], truck: trucks[3], trailer: trailers[1],
    vendor: vendors[3], info: '6000 gal regular',
  ),
  Dispatch.create!(
    origin: origins[1].full_address_with_company,
    destination: dest_locations[5][:location].full_address_with_company,
    destination_location: dest_locations[5][:location],
    dispatch_date: today - 3, status: 'Complete',
    driver: drivers[4], truck: trucks[4], trailer: trailers[3],
    vendor: vendors[2], info: '5500 gal – regular/ULS split',
  ),
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
  ),
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
    vendor: vendors[0], info: '9000 gal regular + ULS',
  ),
  Dispatch.create!(
    origin: origins[2].full_address_with_company,
    destination: dest_locations[6][:location].full_address_with_company,
    destination_location: dest_locations[6][:location],
    dispatch_date: today + 1, status: 'New',
    driver: drivers[4], truck: trucks[4], trailer: trailers[3],
    vendor: vendors[3], info: '5000 gal regular',
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
    vendor: vendors[2], info: '6500 gal regular',
  ),
  Dispatch.create!(
    origin: origins[1].full_address_with_company,
    destination: dest_locations[9][:location].full_address_with_company,
    destination_location: dest_locations[9][:location],
    dispatch_date: today + 4, status: 'New',
    driver: drivers[2], truck: trucks[2], trailer: trailers[0],
    vendor: vendors[2], info: '7500 gal – regular/plus',
  ),
]

DispatchCustomerOrder.create!(dispatch: upcoming_dispatches[0], customer_order: active_orders[3])
DispatchCustomerOrder.create!(dispatch: upcoming_dispatches[1], customer_order: active_orders[4])
DispatchCustomerOrder.create!(dispatch: upcoming_dispatches[2], customer_order: active_orders[5])

# ---------------------------------------------------------------------------
# DISPATCH MESSAGES
# ---------------------------------------------------------------------------
puts "Seeding dispatch messages..."

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
puts "Seeding production orders..."

# Completed production orders
ProductionOrder.create!(
  item: 'Regular Unleaded – 87 Oct Blend',
  product: products[:regular],
  customer: customers[0], location: dest_locations[0][:location],
  qty_to_make: 10000.000, total_qty_produced: 10000.000,
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
  qty_to_make: 12000.000, total_qty_produced: 12000.000,
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

po_in_progress_2 = ProductionOrder.create!(
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

# Pending production orders
ProductionOrder.create!(
  item: 'Plus Midgrade – 89 Oct',
  product: products[:plus],
  customer: customers[0], location: dest_locations[0][:location],
  qty_to_make: 4000.000,
  status: 'pending',
  due_date: today + 3, production_date: today + 2,
  notes: 'Customer requests early morning delivery window 6–8 AM.'
)

ProductionOrder.create!(
  item: 'Ultra Low Sulfur Diesel',
  product: products[:uls],
  customer: customers[7], location: dest_locations[7][:location],
  qty_to_make: 14000.000,
  status: 'pending',
  due_date: today + 3,
  notes: "Large run for Love's 542. Coordinate with dispatch for Trailer 201."
)

ProductionOrder.create!(
  item: 'Reg-E10 Ethanol Blend',
  product: products[:reg_e10],
  customer: customers[3], location: dest_locations[3][:location],
  qty_to_make: 7000.000,
  status: 'pending',
  due_date: today + 4,
  notes: 'Verify ethanol blend ratio before loading. Target 10% ethanol.'
)

ProductionOrder.create!(
  item: 'Dyed ULS Diesel – Farm Tax Exempt',
  product: products[:dyed_uls],
  qty_to_make: 5000.000,
  status: 'pending',
  due_date: today + 6,
  notes: 'Spec order – no customer assigned yet. Hold at terminal pending confirmation.'
)

ProductionOrder.create!(
  item: 'Regular Unleaded – 87 Oct Blend',
  product: products[:regular],
  customer: customers[2], location: dest_locations[2][:location],
  qty_to_make: 6000.000,
  status: 'pending',
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
puts "Seeding work orders..."

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
puts "Seeding announcements..."

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

puts ""
puts "✓ Seed complete!"
puts "  #{User.count} users (#{User.where(role: 'worker').count} drivers)"
puts "  #{Customer.count} customers"
puts "  #{Location.count} locations (#{Location.where(location_category: origin_cat).count} origins, #{Location.where(location_category: destination_cat).count} destinations)"
puts "  #{Product.count} products"
puts "  #{Thing.count} fleet (#{Thing.where(category: 'truck').count} trucks, #{Thing.where(category: 'trailer').count} trailers)"
puts "  #{CustomerOrder.count} customer orders"
puts "  #{Dispatch.count} dispatches"
puts "  #{ProductionOrder.count} production orders"
puts "  #{WorkOrder.count} work orders"
puts ""
puts "  Admin login: admin@perrybrothersoil.com / password123"
