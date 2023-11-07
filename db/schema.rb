# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[7.0].define(version: 2023_11_07_144545) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "customer_orders", force: :cascade do |t|
    t.date "required_delivery_date"
    t.string "product"
    t.bigint "location_id", null: false
    t.float "approximate_product_amount"
    t.text "notes"
    t.string "order_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_customer_orders_on_location_id"
  end

  create_table "dispatch_customer_orders", force: :cascade do |t|
    t.bigint "dispatch_id", null: false
    t.bigint "customer_order_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_order_id"], name: "index_dispatch_customer_orders_on_customer_order_id"
    t.index ["dispatch_id"], name: "index_dispatch_customer_orders_on_dispatch_id"
  end

  create_table "dispatches", force: :cascade do |t|
    t.string "driver_name"
    t.string "origin"
    t.text "info"
    t.date "dispatch_date"
    t.string "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "location_categories", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "location_contacts", force: :cascade do |t|
    t.string "name"
    t.string "email"
    t.string "phone"
    t.bigint "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_location_contacts_on_location_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.text "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  add_foreign_key "customer_orders", "locations"
  add_foreign_key "dispatch_customer_orders", "customer_orders"
  add_foreign_key "dispatch_customer_orders", "dispatches"
  add_foreign_key "location_contacts", "locations"
end
