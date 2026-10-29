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

ActiveRecord::Schema[7.2].define(version: 2026_10_30_120000) do
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
    t.datetime "published_at"
    t.string "status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "app_settings", force: :cascade do |t|
    t.string "key", null: false
    t.string "value"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_app_settings_on_key", unique: true
  end

  create_table "automated_process_configs", force: :cascade do |t|
    t.string "slug"
    t.string "schedule"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "last_triggered_at"
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

  create_table "cost_items", force: :cascade do |t|
    t.string "name", null: false
    t.bigint "reporting_group_id", null: false
    t.decimal "unit_cost", precision: 12, scale: 5, null: false
    t.string "unit"
    t.string "vendor"
    t.date "effective_date"
    t.text "notes"
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_cost_items_on_name", unique: true
    t.index ["reporting_group_id"], name: "index_cost_items_on_reporting_group_id"
  end

  create_table "customer_locations", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.bigint "location_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "pdi_location_id"
    t.index ["customer_id", "location_id"], name: "index_customer_locations_on_customer_id_and_location_id", unique: true
    t.index ["customer_id", "pdi_location_id"], name: "index_customer_locations_on_customer_id_and_pdi_location_id", unique: true
    t.index ["customer_id"], name: "index_customer_locations_on_customer_id"
    t.index ["location_id"], name: "index_customer_locations_on_location_id"
  end

  create_table "customer_order_products", force: :cascade do |t|
    t.bigint "customer_order_id", null: false
    t.integer "quantity"
    t.decimal "price"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "product_name"
    t.string "product_id"
    t.string "warehouse"
    t.string "item_type", default: "buy", null: false
    t.bigint "quote_product_id"
    t.bigint "pricing_rule_id"
    t.decimal "expected_price", precision: 12, scale: 4
    t.string "price_check"
    t.datetime "price_checked_at"
    t.bigint "location_id"
    t.decimal "shipped_quantity", precision: 14, scale: 3
    t.decimal "tax_per_unit", precision: 14, scale: 7
    t.boolean "price_includes_taxes"
    t.index ["customer_order_id"], name: "index_customer_order_products_on_customer_order_id"
    t.index ["location_id"], name: "index_customer_order_products_on_location_id"
    t.index ["price_check"], name: "index_customer_order_products_on_price_check"
    t.index ["pricing_rule_id"], name: "index_customer_order_products_on_pricing_rule_id"
    t.index ["product_id"], name: "index_customer_order_products_on_product_id"
    t.index ["quote_product_id"], name: "index_customer_order_products_on_quote_product_id"
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
    t.string "external_order_no"
    t.datetime "order_date"
    t.string "invoice_no"
    t.string "odor_status"
    t.string "carrier"
    t.date "invoice_date"
    t.string "salesperson"
    t.string "pdi_carrier_id"
    t.bigint "ship_from_location_id"
    t.bigint "freight_origin_location_id"
    t.string "freight_carrier_id"
    t.decimal "freight_miles", precision: 10, scale: 1
    t.integer "freight_extra_stops", default: 0, null: false
    t.integer "freight_pump_offs", default: 0, null: false
    t.string "freight_presentation", default: "line", null: false
    t.datetime "freight_calculated_at"
    t.index ["customer_id"], name: "index_customer_orders_on_customer_id"
    t.index ["external_order_no"], name: "index_customer_orders_on_external_order_no"
    t.index ["freight_origin_location_id"], name: "index_customer_orders_on_freight_origin_location_id"
    t.index ["location_id"], name: "index_customer_orders_on_location_id"
    t.index ["pdi_carrier_id"], name: "index_customer_orders_on_pdi_carrier_id"
    t.index ["ship_from_location_id"], name: "index_customer_orders_on_ship_from_location_id"
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
    t.string "pdi_customer_id"
    t.boolean "active", default: true, null: false
    t.string "pdi_credit_status"
    t.decimal "pdi_credit_limit", precision: 12, scale: 2
    t.decimal "pdi_available_credit", precision: 12, scale: 2
    t.datetime "pdi_credit_updated_at"
    t.integer "lead_time_days"
    t.index ["pdi_customer_id"], name: "index_customers_on_pdi_customer_id", unique: true
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
    t.integer "destination_location_id"
    t.bigint "asset_id"
    t.integer "truck_id"
    t.integer "trailer_id"
    t.string "vendor_id"
    t.string "samsara_route_id"
    t.datetime "samsara_sent_at"
    t.datetime "freight_calculated_at"
    t.bigint "origin_location_id"
    t.index ["asset_id"], name: "index_dispatches_on_asset_id"
    t.index ["origin_location_id"], name: "index_dispatches_on_origin_location_id"
  end

  create_table "dispatches_things", id: false, force: :cascade do |t|
    t.bigint "dispatch_id", null: false
    t.bigint "thing_id", null: false
    t.index ["dispatch_id"], name: "index_dispatches_things_on_dispatch_id"
    t.index ["thing_id"], name: "index_dispatches_things_on_thing_id"
  end

  create_table "freight_classes", force: :cascade do |t|
    t.string "code", null: false
    t.string "name"
    t.decimal "full_load_quantity", precision: 14, scale: 3, null: false
    t.string "unit", default: "gal", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_freight_classes_on_code", unique: true
  end

  create_table "freight_lanes", force: :cascade do |t|
    t.bigint "origin_location_id", null: false
    t.bigint "destination_location_id", null: false
    t.decimal "standard_miles", precision: 10, scale: 1, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["destination_location_id"], name: "index_freight_lanes_on_destination_location_id"
    t.index ["origin_location_id", "destination_location_id"], name: "index_freight_lanes_on_route", unique: true
    t.index ["origin_location_id"], name: "index_freight_lanes_on_origin_location_id"
  end

  create_table "freight_payables", force: :cascade do |t|
    t.string "source_type", null: false
    t.bigint "source_id", null: false
    t.string "vendor_id", null: false
    t.decimal "accrued_amount", precision: 12, scale: 2
    t.decimal "amount", precision: 12, scale: 2
    t.string "invoice_no"
    t.date "invoice_date"
    t.string "bol_number"
    t.string "status", default: "accrued", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["source_type", "source_id", "vendor_id"], name: "index_freight_payables_on_source_and_vendor", unique: true
    t.index ["source_type", "source_id"], name: "index_freight_payables_on_source"
    t.index ["status"], name: "index_freight_payables_on_status"
  end

  create_table "freight_rules", force: :cascade do |t|
    t.string "name", null: false
    t.string "side", null: false
    t.string "charge_type", default: "freight", null: false
    t.string "basis", null: false
    t.bigint "freight_table_id"
    t.bigint "origin_location_id"
    t.bigint "freight_class_id"
    t.string "carrier_id"
    t.bigint "customer_id"
    t.decimal "markup_percent", precision: 8, scale: 3
    t.decimal "minimum_amount", precision: 12, scale: 2
    t.date "effective_from", null: false
    t.date "effective_to"
    t.boolean "active", default: true, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "calculation", default: "order", null: false
    t.boolean "bill_full_load", default: false, null: false
    t.index ["carrier_id"], name: "index_freight_rules_on_carrier_id"
    t.index ["customer_id"], name: "index_freight_rules_on_customer_id"
    t.index ["freight_class_id"], name: "index_freight_rules_on_freight_class_id"
    t.index ["freight_table_id"], name: "index_freight_rules_on_freight_table_id"
    t.index ["origin_location_id"], name: "index_freight_rules_on_origin_location_id"
    t.index ["side", "charge_type", "active"], name: "index_freight_rules_on_side_and_charge_type_and_active"
  end

  create_table "freight_table_rates", force: :cascade do |t|
    t.bigint "freight_table_id", null: false
    t.bigint "origin_location_id"
    t.bigint "destination_location_id"
    t.decimal "miles_from", precision: 10, scale: 2
    t.decimal "miles_to", precision: 10, scale: 2
    t.decimal "rate", precision: 12, scale: 4, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["destination_location_id"], name: "index_freight_table_rates_on_destination_location_id"
    t.index ["freight_table_id"], name: "index_freight_table_rates_on_freight_table_id"
    t.index ["origin_location_id"], name: "index_freight_table_rates_on_origin_location_id"
  end

  create_table "freight_tables", force: :cascade do |t|
    t.string "name", null: false
    t.string "lookup_type", default: "mileage", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_freight_tables_on_name", unique: true
  end

  create_table "inventory_cost_histories", force: :cascade do |t|
    t.string "product_id", null: false
    t.decimal "amount", precision: 12, scale: 4
    t.decimal "previous_amount", precision: 12, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "created_at"], name: "index_inventory_cost_histories_on_product_id_and_created_at"
  end

  create_table "inventory_cost_layers", force: :cascade do |t|
    t.string "product_id", null: false
    t.bigint "location_id", null: false
    t.bigint "inventory_transaction_id"
    t.date "received_on", null: false
    t.decimal "quantity", precision: 14, scale: 3, null: false
    t.decimal "remaining_quantity", precision: 14, scale: 3, null: false
    t.decimal "unit_cost", precision: 14, scale: 6, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_transaction_id"], name: "index_inventory_cost_layers_on_inventory_transaction_id"
    t.index ["location_id"], name: "index_inventory_cost_layers_on_location_id"
    t.index ["product_id", "location_id", "received_on"], name: "idx_on_product_id_location_id_received_on_12f4e51ed1"
  end

  create_table "inventory_layer_draws", force: :cascade do |t|
    t.bigint "inventory_transaction_id", null: false
    t.bigint "inventory_cost_layer_id", null: false
    t.decimal "quantity", precision: 14, scale: 3, null: false
    t.decimal "unit_cost", precision: 14, scale: 6, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["inventory_cost_layer_id"], name: "index_inventory_layer_draws_on_inventory_cost_layer_id"
    t.index ["inventory_transaction_id"], name: "index_inventory_layer_draws_on_inventory_transaction_id"
  end

  create_table "inventory_transactions", force: :cascade do |t|
    t.decimal "quantity", precision: 14, scale: 3, null: false
    t.string "direction", null: false
    t.string "transactable_type"
    t.bigint "transactable_id"
    t.string "reference_number"
    t.text "notes"
    t.bigint "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "product_id", null: false
    t.bigint "location_id"
    t.bigint "reversal_of_id"
    t.string "movement_type"
    t.date "occurred_on"
    t.decimal "unit_cost", precision: 14, scale: 6
    t.decimal "total_cost", precision: 16, scale: 4
    t.decimal "variance_amount", precision: 16, scale: 4
    t.decimal "balance_quantity", precision: 14, scale: 3
    t.decimal "balance_value", precision: 16, scale: 4
    t.bigint "ledger_entry_id"
    t.datetime "gl_posted_at"
    t.index ["created_by_id"], name: "index_inventory_transactions_on_created_by_id"
    t.index ["ledger_entry_id"], name: "index_inventory_transactions_on_ledger_entry_id"
    t.index ["movement_type"], name: "index_inventory_transactions_on_movement_type"
    t.index ["product_id", "location_id", "occurred_on"], name: "idx_on_product_id_location_id_occurred_on_2cf8b664e6"
    t.index ["product_id"], name: "index_inventory_transactions_on_product_id"
    t.index ["reversal_of_id"], name: "index_inventory_transactions_on_reversal_of_id", unique: true
    t.index ["transactable_type", "transactable_id"], name: "idx_inv_trans_on_transactable"
  end

  create_table "job_workers", force: :cascade do |t|
    t.bigint "job_id", null: false
    t.bigint "user_id", null: false
    t.datetime "clocked_in_at", null: false
    t.datetime "clocked_out_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_id"], name: "index_job_workers_on_job_id"
    t.index ["user_id"], name: "index_job_workers_on_user_id"
  end

  create_table "jobs", force: :cascade do |t|
    t.bigint "production_order_id", null: false
    t.bigint "created_by_id", null: false
    t.string "job_type", null: false
    t.datetime "started_at", null: false
    t.datetime "ended_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "edited_by_id"
    t.datetime "edited_at"
    t.index ["created_by_id"], name: "index_jobs_on_created_by_id"
    t.index ["edited_by_id"], name: "index_jobs_on_edited_by_id"
    t.index ["production_order_id"], name: "index_jobs_on_production_order_id"
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.string "reference_number", null: false
    t.date "reference_date", null: false
    t.string "description", null: false
    t.string "journal_id", null: false
    t.string "status", default: "approved", null: false
    t.datetime "approved_at", null: false
    t.datetime "exported_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "production_order_id"
    t.bigint "reversal_of_id"
    t.bigint "approved_by_id"
    t.bigint "sync_log_id"
    t.string "source_type"
    t.bigint "source_id"
    t.index ["approved_by_id"], name: "index_ledger_entries_on_approved_by_id"
    t.index ["production_order_id"], name: "index_ledger_entries_on_production_order_id"
    t.index ["reference_number"], name: "index_ledger_entries_on_reference_number", unique: true
    t.index ["reversal_of_id"], name: "index_ledger_entries_on_reversal_of_id", unique: true
    t.index ["source_type", "source_id"], name: "index_ledger_entries_on_source"
    t.index ["sync_log_id"], name: "index_ledger_entries_on_sync_log_id"
  end

  create_table "ledger_lines", force: :cascade do |t|
    t.bigint "ledger_entry_id", null: false
    t.integer "position", null: false
    t.string "posting"
    t.string "account", null: false
    t.string "line_description", null: false
    t.decimal "debit", precision: 12, scale: 2
    t.decimal "credit", precision: 12, scale: 2
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["ledger_entry_id"], name: "index_ledger_lines_on_ledger_entry_id"
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
    t.integer "max_capacity"
    t.integer "uleage_90"
    t.integer "cutoff"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "product_id", null: false
    t.decimal "quantity", precision: 14, scale: 3, default: "0.0", null: false
    t.decimal "inventory_value", precision: 16, scale: 4, default: "0.0", null: false
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
    t.boolean "show_in_warehouse_dropdown", default: false, null: false
    t.string "pdi_site_code"
    t.string "pdi_terminal_id"
    t.string "samsara_address_id"
    t.index ["location_category_id"], name: "index_locations_on_location_category_id"
    t.index ["pdi_terminal_id"], name: "index_locations_on_pdi_terminal_id", unique: true
    t.index ["samsara_address_id"], name: "index_locations_on_samsara_address_id"
  end

  create_table "locations_products", id: false, force: :cascade do |t|
    t.bigint "location_id", null: false
    t.string "product_id", null: false
    t.index ["location_id"], name: "index_locations_products_on_location_id"
    t.index ["product_id"], name: "index_locations_products_on_product_id"
  end

  create_table "order_freight_charges", force: :cascade do |t|
    t.bigint "customer_order_id", null: false
    t.string "side", null: false
    t.string "charge_type", default: "freight", null: false
    t.string "description"
    t.bigint "freight_rule_id"
    t.bigint "freight_class_id"
    t.string "carrier_id"
    t.string "basis"
    t.decimal "quantity", precision: 14, scale: 3
    t.decimal "rate", precision: 12, scale: 4
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.boolean "calculated", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "dispatch_id"
    t.index ["customer_order_id"], name: "index_order_freight_charges_on_customer_order_id"
    t.index ["dispatch_id"], name: "index_order_freight_charges_on_dispatch_id"
    t.index ["freight_class_id"], name: "index_order_freight_charges_on_freight_class_id"
    t.index ["freight_rule_id"], name: "index_order_freight_charges_on_freight_rule_id"
  end

  create_table "pdi_carriers", force: :cascade do |t|
    t.string "pdi_carrier_id", null: false
    t.string "name", null: false
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["pdi_carrier_id"], name: "index_pdi_carriers_on_pdi_carrier_id", unique: true
  end

  create_table "phone_numbers", force: :cascade do |t|
    t.bigint "customer_id", null: false
    t.string "number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_phone_numbers_on_customer_id"
  end

  create_table "pricing_rule_products", force: :cascade do |t|
    t.integer "pricing_rule_id"
    t.string "product_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "pricing_rules", force: :cascade do |t|
    t.string "name"
    t.integer "customer_id"
    t.string "pricing_basis"
    t.string "pricing_method"
    t.decimal "value", precision: 12, scale: 4
    t.date "effective_date"
    t.date "expiration_date"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "product_components", force: :cascade do |t|
    t.decimal "quantity_per_unit", precision: 12, scale: 4
    t.string "uom"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "product_id", null: false
    t.string "component_product_id", null: false
    t.index ["component_product_id"], name: "index_product_components_on_component_product_id"
    t.index ["product_id"], name: "index_product_components_on_product_id"
  end

  create_table "product_cost_lines", force: :cascade do |t|
    t.string "product_id", null: false
    t.bigint "reporting_group_id", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 12, scale: 4, default: "1.0", null: false
    t.decimal "unit_cost", precision: 12, scale: 4
    t.decimal "per_quantity", precision: 12, scale: 4, default: "1.0", null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "cost_item_id"
    t.index ["cost_item_id"], name: "index_product_cost_lines_on_cost_item_id"
    t.index ["product_id"], name: "index_product_cost_lines_on_product_id"
    t.index ["reporting_group_id"], name: "index_product_cost_lines_on_reporting_group_id"
  end

  create_table "product_vendors", force: :cascade do |t|
    t.string "product_id", null: false
    t.string "vendor_id", null: false
    t.integer "priority", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id", "priority"], name: "index_product_vendors_on_product_id_and_priority"
    t.index ["product_id", "vendor_id"], name: "index_product_vendors_on_product_id_and_vendor_id", unique: true
  end

  create_table "production_order_batches", force: :cascade do |t|
    t.bigint "production_order_id", null: false
    t.string "batch_number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "quantity", precision: 12, scale: 3
    t.string "lot_number"
    t.string "qc_status", default: "pending"
    t.text "qc_notes"
    t.string "qc_by"
    t.datetime "qc_at"
    t.datetime "completed_at"
    t.index ["lot_number"], name: "index_production_order_batches_on_lot_number", unique: true
    t.index ["production_order_id"], name: "index_production_order_batches_on_production_order_id"
  end

  create_table "production_order_components", force: :cascade do |t|
    t.bigint "production_order_id", null: false
    t.decimal "quantity", precision: 12, scale: 3
    t.string "uom"
    t.string "part_number"
    t.string "description"
    t.string "confirmed_by"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "quantity_actual", precision: 12, scale: 3
    t.string "product_id"
    t.index ["product_id"], name: "index_production_order_components_on_product_id"
    t.index ["production_order_id", "position"], name: "idx_poc_on_po_id_pos"
    t.index ["production_order_id"], name: "index_production_order_components_on_production_order_id"
  end

  create_table "production_orders", force: :cascade do |t|
    t.string "number"
    t.string "status"
    t.date "due_date"
    t.string "customer_name"
    t.string "location_name"
    t.integer "priority"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "item"
    t.string "batch_number"
    t.decimal "qty_to_make", precision: 12, scale: 3
    t.text "production_notes"
    t.date "date_started"
    t.date "date_completed"
    t.decimal "total_qty_produced", precision: 12, scale: 3
    t.string "filled_by"
    t.string "approved_by"
    t.bigint "customer_id"
    t.bigint "location_id"
    t.date "production_date"
    t.string "product_id"
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.text "void_reason"
    t.string "lot_number"
    t.index ["customer_id"], name: "index_production_orders_on_customer_id"
    t.index ["location_id"], name: "index_production_orders_on_location_id"
    t.index ["lot_number"], name: "index_production_orders_on_lot_number", unique: true
    t.index ["number"], name: "index_production_orders_on_number", unique: true
    t.index ["product_id"], name: "index_production_orders_on_product_id"
    t.index ["voided_by_id"], name: "index_production_orders_on_voided_by_id"
  end

  create_table "products", id: :string, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "unit_of_measurement"
    t.decimal "weight"
    t.boolean "is_raw_material", default: false, null: false
    t.decimal "current_stock", precision: 14, scale: 3, default: "0.0"
    t.decimal "reorder_point", precision: 14, scale: 3
    t.decimal "safety_stock", precision: 14, scale: 3, default: "0.0"
    t.decimal "cost_per_unit", precision: 12, scale: 4
    t.string "pdi_package_code"
    t.string "category"
    t.decimal "max_stock"
    t.string "pdi_tank_id"
    t.decimal "standard_cost", precision: 12, scale: 4
    t.decimal "pdi_repack_fee", precision: 12, scale: 4
    t.string "coa_note"
    t.boolean "active", default: true, null: false
    t.integer "lead_time_days"
    t.integer "production_days"
    t.bigint "freight_class_id"
    t.index ["freight_class_id"], name: "index_products_on_freight_class_id"
  end

  create_table "purchase_order_line_items", force: :cascade do |t|
    t.bigint "purchase_order_id", null: false
    t.string "product_id"
    t.string "product_name"
    t.decimal "quantity", precision: 14, scale: 3
    t.decimal "unit_cost", precision: 12, scale: 4
    t.string "package_code"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_purchase_order_line_items_on_product_id"
    t.index ["purchase_order_id"], name: "index_purchase_order_line_items_on_purchase_order_id"
  end

  create_table "purchase_orders", force: :cascade do |t|
    t.string "status", default: "draft", null: false
    t.string "trigger_type"
    t.text "trigger_reason"
    t.bigint "approved_by_id"
    t.datetime "submitted_at"
    t.date "expected_delivery_date"
    t.datetime "received_at"
    t.bigint "received_by_id"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "vendor_id"
    t.string "pdi_reference"
    t.datetime "posted_at"
    t.string "freight_terms"
    t.decimal "freight_amount", precision: 10, scale: 2
    t.decimal "other_charges", precision: 10, scale: 2
    t.string "other_charges_description"
    t.bigint "location_id"
    t.datetime "voided_at"
    t.bigint "voided_by_id"
    t.text "void_reason"
    t.string "pdi_po_key"
    t.string "freight_allocation"
    t.string "freight_source", default: "vendor_invoice", null: false
    t.string "freight_vendor_id"
    t.string "freight_bol"
    t.boolean "freight_accrued", default: false, null: false
    t.index ["pdi_po_key"], name: "index_purchase_orders_on_pdi_po_key", unique: true
    t.index ["pdi_reference"], name: "index_purchase_orders_on_pdi_reference"
    t.index ["status"], name: "index_purchase_orders_on_status"
    t.index ["trigger_type"], name: "index_purchase_orders_on_trigger_type"
    t.index ["voided_by_id"], name: "index_purchase_orders_on_voided_by_id"
  end

  create_table "quality_results", force: :cascade do |t|
    t.bigint "production_order_id", null: false
    t.bigint "quality_spec_id"
    t.string "section"
    t.string "name", null: false
    t.string "test_method"
    t.string "result_type", default: "numeric", null: false
    t.string "expected"
    t.string "unit"
    t.decimal "target_min", precision: 12, scale: 4
    t.decimal "target_max", precision: 12, scale: 4
    t.string "qualifier"
    t.decimal "value", precision: 12, scale: 4
    t.boolean "passed"
    t.boolean "in_range", default: false, null: false
    t.text "notes"
    t.bigint "tested_by_id"
    t.datetime "tested_at", null: false
    t.bigint "reviewed_by_id"
    t.datetime "reviewed_at"
    t.text "resolution"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["production_order_id", "quality_spec_id"], name: "idx_on_production_order_id_quality_spec_id_43ef9b5c4b", unique: true
    t.index ["production_order_id"], name: "index_quality_results_on_production_order_id"
    t.index ["quality_spec_id"], name: "index_quality_results_on_quality_spec_id"
    t.index ["reviewed_by_id"], name: "index_quality_results_on_reviewed_by_id"
    t.index ["tested_by_id"], name: "index_quality_results_on_tested_by_id"
  end

  create_table "quality_specs", force: :cascade do |t|
    t.string "product_id", null: false
    t.string "section"
    t.string "name", null: false
    t.string "test_method"
    t.string "result_type", default: "numeric", null: false
    t.string "expected"
    t.string "unit"
    t.decimal "target_min", precision: 12, scale: 4
    t.decimal "target_max", precision: 12, scale: 4
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["product_id"], name: "index_quality_specs_on_product_id"
  end

  create_table "quote_products", force: :cascade do |t|
    t.bigint "quote_id", null: false
    t.string "product_id"
    t.string "product_name"
    t.decimal "quantity", precision: 14, scale: 3
    t.decimal "price", precision: 12, scale: 4
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.bigint "pricing_rule_id"
    t.string "pricing_basis"
    t.string "pricing_method"
    t.decimal "rule_value", precision: 12, scale: 4
    t.decimal "basis_cost", precision: 12, scale: 4
    t.boolean "price_overridden", default: false, null: false
    t.date "superseded_on"
    t.datetime "priced_at"
    t.index ["pricing_rule_id"], name: "index_quote_products_on_pricing_rule_id"
    t.index ["product_id"], name: "index_quote_products_on_product_id"
    t.index ["quote_id"], name: "index_quote_products_on_quote_id"
  end

  create_table "quotes", force: :cascade do |t|
    t.string "quote_number", null: false
    t.bigint "customer_id", null: false
    t.bigint "location_id"
    t.string "status", default: "draft", null: false
    t.date "expiry_date"
    t.text "notes"
    t.datetime "sent_at"
    t.bigint "customer_order_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.date "valid_from"
    t.boolean "locks_pricing", default: false, null: false
    t.datetime "accepted_at"
    t.bigint "accepted_by_id"
    t.date "lock_ended_on"
    t.datetime "lock_ended_at"
    t.text "lock_end_reason"
    t.bigint "lock_ended_by_id"
    t.index ["accepted_by_id"], name: "index_quotes_on_accepted_by_id"
    t.index ["customer_id"], name: "index_quotes_on_customer_id"
    t.index ["customer_order_id"], name: "index_quotes_on_customer_order_id"
    t.index ["location_id"], name: "index_quotes_on_location_id"
    t.index ["lock_ended_by_id"], name: "index_quotes_on_lock_ended_by_id"
    t.index ["quote_number"], name: "index_quotes_on_quote_number", unique: true
  end

  create_table "reporting_groups", force: :cascade do |t|
    t.string "name", null: false
    t.string "item_type", null: false
    t.string "gl_account"
    t.string "temp_gl_account"
    t.boolean "labor", default: false, null: false
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "post_inventory_gl", default: false, null: false
    t.string "costing_method", default: "weighted_average", null: false
    t.string "inventory_gl_account"
    t.string "cogs_gl_account"
    t.string "ppv_gl_account"
    t.string "receipts_clearing_gl_account"
    t.string "adjustment_gl_account"
    t.string "revaluation_gl_account"
    t.boolean "buy", default: false, null: false
    t.index ["name"], name: "index_reporting_groups_on_name", unique: true
  end

  create_table "standard_cost_histories", force: :cascade do |t|
    t.string "product_id"
    t.decimal "amount", precision: 12, scale: 4
    t.date "effective_date"
    t.integer "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "notes"
  end

  create_table "sync_logs", force: :cascade do |t|
    t.string "process_name"
    t.string "status"
    t.string "file_name"
    t.datetime "started_at"
    t.datetime "completed_at"
    t.integer "records_created"
    t.integer "records_updated"
    t.integer "records_skipped"
    t.text "error_message"
    t.text "warnings"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.text "file_content"
    t.boolean "file_binary"
  end

  create_table "things", force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "category", default: "truck", null: false
    t.bigint "dispatch_id"
    t.index ["dispatch_id"], name: "index_things_on_dispatch_id"
  end

  create_table "user_favorites", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "label"
    t.string "path"
    t.integer "position"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "path"], name: "index_user_favorites_on_user_id_and_path", unique: true
    t.index ["user_id"], name: "index_user_favorites_on_user_id"
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
    t.string "employment_type", default: "full_time", null: false
    t.jsonb "permissions", default: {}, null: false
    t.datetime "deactivated_at"
    t.jsonb "list_filters", default: {}, null: false
    t.string "samsara_driver_id"
    t.bigint "home_location_id"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["home_location_id"], name: "index_users_on_home_location_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
  end

  create_table "vendor_freight_terms", force: :cascade do |t|
    t.string "vendor_id", null: false
    t.string "freight_term", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["vendor_id", "freight_term"], name: "index_vendor_freight_terms_on_vendor_id_and_freight_term", unique: true
  end

  create_table "vendors", id: :string, force: :cascade do |t|
    t.string "name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "lead_time_days"
    t.string "contact_name"
    t.string "email"
    t.string "phone"
    t.string "address_1"
    t.string "address_2"
    t.string "city"
    t.string "state"
    t.string "zip"
    t.string "payment_terms"
    t.string "payment_method"
    t.string "freight_terms"
  end

  create_table "work_orders", force: :cascade do |t|
    t.string "subject"
    t.integer "assigned_to"
    t.string "attachments"
    t.string "status"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "workable_type", null: false
    t.bigint "workable_id", null: false
    t.string "vendor_id"
    t.index ["workable_type", "workable_id"], name: "index_work_orders_on_workable"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "comments", "users"
  add_foreign_key "comments", "work_orders"
  add_foreign_key "cost_items", "reporting_groups"
  add_foreign_key "customer_locations", "customers"
  add_foreign_key "customer_locations", "locations"
  add_foreign_key "customer_order_products", "customer_orders"
  add_foreign_key "customer_order_products", "locations"
  add_foreign_key "customer_order_products", "pricing_rules", on_delete: :nullify
  add_foreign_key "customer_order_products", "products"
  add_foreign_key "customer_order_products", "quote_products", on_delete: :nullify
  add_foreign_key "customer_orders", "customers"
  add_foreign_key "customer_orders", "locations", column: "freight_origin_location_id"
  add_foreign_key "customer_orders", "locations", column: "ship_from_location_id"
  add_foreign_key "customer_orders", "locations", on_delete: :cascade
  add_foreign_key "dispatch_customer_orders", "customer_orders", on_delete: :cascade
  add_foreign_key "dispatch_customer_orders", "dispatches"
  add_foreign_key "dispatch_messages", "dispatches"
  add_foreign_key "dispatch_messages", "users"
  add_foreign_key "dispatches", "locations", column: "origin_location_id"
  add_foreign_key "dispatches", "things", column: "asset_id"
  add_foreign_key "dispatches", "vendors"
  add_foreign_key "freight_lanes", "locations", column: "destination_location_id"
  add_foreign_key "freight_lanes", "locations", column: "origin_location_id"
  add_foreign_key "freight_payables", "vendors"
  add_foreign_key "freight_rules", "customers"
  add_foreign_key "freight_rules", "freight_classes"
  add_foreign_key "freight_rules", "freight_tables"
  add_foreign_key "freight_rules", "locations", column: "origin_location_id"
  add_foreign_key "freight_rules", "vendors", column: "carrier_id"
  add_foreign_key "freight_table_rates", "freight_tables"
  add_foreign_key "freight_table_rates", "locations", column: "destination_location_id"
  add_foreign_key "freight_table_rates", "locations", column: "origin_location_id"
  add_foreign_key "inventory_cost_layers", "inventory_transactions"
  add_foreign_key "inventory_cost_layers", "locations"
  add_foreign_key "inventory_layer_draws", "inventory_cost_layers"
  add_foreign_key "inventory_layer_draws", "inventory_transactions"
  add_foreign_key "inventory_transactions", "inventory_transactions", column: "reversal_of_id"
  add_foreign_key "inventory_transactions", "ledger_entries"
  add_foreign_key "inventory_transactions", "products"
  add_foreign_key "job_workers", "jobs"
  add_foreign_key "job_workers", "users"
  add_foreign_key "jobs", "production_orders"
  add_foreign_key "jobs", "users", column: "created_by_id"
  add_foreign_key "jobs", "users", column: "edited_by_id"
  add_foreign_key "ledger_entries", "ledger_entries", column: "reversal_of_id"
  add_foreign_key "ledger_entries", "production_orders"
  add_foreign_key "ledger_entries", "sync_logs"
  add_foreign_key "ledger_entries", "users", column: "approved_by_id"
  add_foreign_key "ledger_lines", "ledger_entries"
  add_foreign_key "location_contacts", "locations"
  add_foreign_key "location_products", "locations", on_delete: :cascade
  add_foreign_key "location_products", "products"
  add_foreign_key "locations", "location_categories"
  add_foreign_key "order_freight_charges", "customer_orders"
  add_foreign_key "order_freight_charges", "dispatches"
  add_foreign_key "order_freight_charges", "freight_classes"
  add_foreign_key "order_freight_charges", "freight_rules"
  add_foreign_key "order_freight_charges", "vendors", column: "carrier_id"
  add_foreign_key "phone_numbers", "customers"
  add_foreign_key "product_components", "products"
  add_foreign_key "product_components", "products", column: "component_product_id"
  add_foreign_key "product_cost_lines", "cost_items"
  add_foreign_key "product_cost_lines", "reporting_groups"
  add_foreign_key "product_vendors", "products"
  add_foreign_key "product_vendors", "vendors"
  add_foreign_key "production_order_batches", "production_orders"
  add_foreign_key "production_order_components", "production_orders"
  add_foreign_key "production_order_components", "products"
  add_foreign_key "production_orders", "customers"
  add_foreign_key "production_orders", "locations"
  add_foreign_key "production_orders", "products"
  add_foreign_key "production_orders", "users", column: "voided_by_id"
  add_foreign_key "products", "freight_classes"
  add_foreign_key "purchase_order_line_items", "purchase_orders"
  add_foreign_key "purchase_orders", "users", column: "voided_by_id"
  add_foreign_key "purchase_orders", "vendors"
  add_foreign_key "quality_results", "production_orders"
  add_foreign_key "quality_results", "quality_specs", on_delete: :nullify
  add_foreign_key "quality_results", "users", column: "reviewed_by_id"
  add_foreign_key "quality_results", "users", column: "tested_by_id"
  add_foreign_key "quote_products", "pricing_rules", on_delete: :nullify
  add_foreign_key "quote_products", "products"
  add_foreign_key "quote_products", "quotes"
  add_foreign_key "quotes", "customer_orders"
  add_foreign_key "quotes", "customers"
  add_foreign_key "quotes", "locations"
  add_foreign_key "quotes", "users", column: "accepted_by_id"
  add_foreign_key "quotes", "users", column: "lock_ended_by_id"
  add_foreign_key "things", "dispatches"
  add_foreign_key "user_favorites", "users"
  add_foreign_key "users", "locations", column: "home_location_id"
  add_foreign_key "work_orders", "vendors"
end
