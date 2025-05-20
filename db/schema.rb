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

ActiveRecord::Schema[7.0].define(version: 2025_05_19_182631) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "announcements", force: :cascade do |t|
    t.string "title"
    t.text "content"
    t.datetime "published_at"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "comments", force: :cascade do |t|
    t.text "content"
    t.bigint "user_id", null: false
    t.bigint "work_order_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_comments_on_user_id"
    t.index ["work_order_id"], name: "index_comments_on_work_order_id"
  end

  create_table "customer_locations", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_customer_locations_on_customer_id"
    t.index ["location_id"], name: "index_customer_locations_on_location_id"
  end

  create_table "customer_order_products", force: :cascade do |t|
    t.bigint "customer_order_id", null: false
    t.bigint "product_id", null: false
    t.integer "quantity"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_order_id"], name: "index_customer_order_products_on_customer_order_id"
    t.index ["product_id"], name: "index_customer_order_products_on_product_id"
  end

  create_table "customer_orders", force: :cascade do |t|
    t.date "required_delivery_date"
    t.string "product"
    t.bigint "location_id", null: false
    t.float "approximate_product_amount"
    t.text "notes"
    t.string "order_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "card_color"
    t.bigint "customer_id"
    t.boolean "freight_only"
    t.index ["customer_id"], name: "index_customer_orders_on_customer_id"
    t.index ["location_id"], name: "index_customer_orders_on_location_id"
  end

  create_table "customer_orders_things", id: false, force: :cascade do |t|
    t.bigint "customer_order_id", null: false
    t.bigint "thing_id", null: false
    t.index ["customer_order_id"], name: "index_customer_orders_things_on_customer_order_id"
    t.index ["thing_id"], name: "index_customer_orders_things_on_thing_id"
  end

  create_table "customers", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email"
    t.string "phone"
    t.string "preferred_contact_method", default: "no preference"
  end

  create_table "dispatch_customer_orders", force: :cascade do |t|
    t.bigint "dispatch_id", null: false
    t.bigint "customer_order_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_order_id"], name: "index_dispatch_customer_orders_on_customer_order_id"
    t.index ["dispatch_id"], name: "index_dispatch_customer_orders_on_dispatch_id"
  end

  create_table "dispatch_messages", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "message_body", null: false
    t.string "delivery_method", null: false
    t.datetime "sent_at"
    t.string "status", default: "pending"
    t.string "reference_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "dispatch_id"
    t.index ["dispatch_id"], name: "index_dispatch_messages_on_dispatch_id"
    t.index ["user_id"], name: "index_dispatch_messages_on_user_id"
  end

  create_table "dispatches", force: :cascade do |t|
    t.string "origin"
    t.text "info"
    t.date "dispatch_date"
    t.string "status"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "position"
    t.integer "driver_id"
    t.string "destination"
    t.boolean "needs_updating"
    t.bigint "vendor_id"
    t.integer "destination_location_id"
    t.bigint "asset_id"
    t.integer "truck_id"
    t.integer "trailer_id"
    t.index ["asset_id"], name: "index_dispatches_on_asset_id"
    t.index ["vendor_id"], name: "index_dispatches_on_vendor_id"
  end

  create_table "dispatches_things", id: false, force: :cascade do |t|
    t.bigint "dispatch_id", null: false
    t.bigint "thing_id", null: false
    t.index ["dispatch_id"], name: "index_dispatches_things_on_dispatch_id"
    t.index ["thing_id"], name: "index_dispatches_things_on_thing_id"
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

  create_table "location_products", force: :cascade do |t|
    t.bigint "location_id", null: false
    t.bigint "product_id", null: false
    t.integer "max_capacity"
    t.integer "uleage_90"
    t.integer "cutoff"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_location_products_on_location_id"
    t.index ["product_id"], name: "index_location_products_on_product_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "city"
    t.text "address"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "location_category_id"
    t.string "company_name"
    t.string "phone_number"
    t.text "notes"
    t.string "state"
    t.string "zip"
    t.integer "max_capacity"
    t.integer "uleage_90"
    t.integer "cutoff_percent"
    t.float "latitude"
    t.float "longitude"
    t.string "marker_color"
    t.boolean "disabled"
    t.index ["location_category_id"], name: "index_locations_on_location_category_id"
  end

  create_table "locations_products", id: false, force: :cascade do |t|
    t.bigint "location_id", null: false
    t.bigint "product_id", null: false
    t.index ["location_id"], name: "index_locations_products_on_location_id"
    t.index ["product_id"], name: "index_locations_products_on_product_id"
  end

  create_table "phone_numbers", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_phone_numbers_on_customer_id"
  end

  create_table "products", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "unit_of_measurement"
    t.decimal "weight"
  end

  create_table "things", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category", default: "truck", null: false
    t.bigint "dispatch_id"
    t.index ["dispatch_id"], name: "index_things_on_dispatch_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.string "first_name"
    t.string "last_name"
    t.string "phone_number"
    t.string "role", default: "worker"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "email_opt_in"
    t.boolean "sms_opt_in"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vendors", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "work_orders", force: :cascade do |t|
    t.string "subject"
    t.integer "assigned_to"
    t.string "attachments"
    t.bigint "vendor_id"
    t.string "status"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "workable_type", null: false
    t.bigint "workable_id", null: false
    t.index ["vendor_id"], name: "index_work_orders_on_vendor_id"
    t.index ["workable_type", "workable_id"], name: "index_work_orders_on_workable"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "users"
  add_foreign_key "comments", "work_orders"
  add_foreign_key "customer_locations", "customers"
  add_foreign_key "customer_locations", "locations"
  add_foreign_key "customer_order_products", "customer_orders"
  add_foreign_key "customer_order_products", "products"
  add_foreign_key "customer_orders", "customers"
  add_foreign_key "customer_orders", "locations", on_delete: :cascade
  add_foreign_key "dispatch_customer_orders", "customer_orders", on_delete: :cascade
  add_foreign_key "dispatch_customer_orders", "dispatches"
  add_foreign_key "dispatch_messages", "dispatches"
  add_foreign_key "dispatch_messages", "users"
  add_foreign_key "dispatches", "things", column: "asset_id"
  add_foreign_key "dispatches", "vendors"
  add_foreign_key "location_contacts", "locations"
  add_foreign_key "location_products", "locations", on_delete: :cascade
  add_foreign_key "location_products", "products"
  add_foreign_key "locations", "location_categories"
  add_foreign_key "phone_numbers", "customers"
  add_foreign_key "things", "dispatches"
  add_foreign_key "work_orders", "vendors"
end
