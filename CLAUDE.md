# LoadNTrucks — Claude Code Context

## What this app is
Ruby on Rails 7.0.8 + PostgreSQL app for **Perry Brothers Oil** (Five Points Service),
Americus/Albany GA area. Manages petroleum product dispatch, customer orders,
driver/truck tracking, vendor management, location/terminal management, production
orders (DEF manufacturing), MRP/inventory, purchasing, and pricing. Integrates with
**PDI** (the ERP/accounting system) via FTP file exchange. Live at **loadntrucks.com**,
hosted on Render.

Primary contact: John (admin@perrybrothersoil.com)

---

## Stack
- Ruby 3.1.2, Rails 7.0.8, PostgreSQL 15
- Bootstrap 5, Leaflet.js (maps), Select2, FullCalendar
- jsbundling-rails (esbuild) + cssbundling-rails (sass via yarn)
- Devise authentication + **Cloudflare Turnstile** on registration (reCAPTCHA was removed)
- Samsara Fleet API for live GPS truck tracking
- Twilio for SMS (dispatch notifications / messages)
- roo / roo-xls for spreadsheet imports, net-ftp for PDI, fugit for cron parsing
- Render for production hosting (uses DATABASE_URL env var)
- SendGrid for email (ActionMailer configured in production)
- Active Job with default :async adapter (no Sidekiq, no queue backend)

---

## Local dev setup
- `config/database.yml` and `.env` are gitignored and must be created locally
- Run everything: `bin/dev` (Procfile.dev: rails server + `yarn build --watch` + `yarn watch:css`)
- Or just the server: `bundle exec rails server` (run `yarn build && yarn build:css` first if assets are missing)
- Gemfile pins Ruby **3.1.2** — make sure rbenv has it installed
- Windows quirks (from earlier dev on Windows 10): Puma workers/threads limited via
  `Gem.win_platform?` guard in config/puma.rb; Sprockets uses MemoryStore cache in
  config/environments/development.rb. On Windows, PG15 was on port 5433.

---

## Key domain concepts

**Locations** = terminals (origin, category_id: 1) or customer delivery sites (destination, category_id: 2).
Locations also act as warehouses/tanks for inventory (`show_in_warehouse_dropdown`, `pdi_site_code`).
**Dispatches** = a driver assignment linking an origin terminal to customer orders. Status: "Sent to Driver" shows on map.
**CustomerOrder** = `order_status` enum mirrors **PDI order statuses** (Open Order, Quote, Pending,
Released for Dispatch, Dispatched, Released for Picking, Picking in Progress, Shipped,
Released for Billing, Billed, Delivered, Accepted/Rejected by Site, Expired, Expired Quote,
Cancelled as Order/Quote, Quarantine). "Open" work = `CustomerOrder::ACTIVE_STATUSES`.
Orders mostly arrive via the PDI order sync.
**Quotes** = price agreements (draft → sent → accepted/rejected). Lines are priced from pricing
rules and store a snapshot (rule, basis, basis_cost, method, value, price_overridden). An accepted
quote with `locks_pricing` locks its prices for that customer from `valid_from` through `expiry_date`;
`PricingRuleService.lookup` checks `QuoteProduct.active_lock_for` before the rules. Accepting a newer
quote sets `superseded_on` on the customer's older lines for the same products (lock ends the day
before). Quotes created before Oct 2026 have `locks_pricing: false` and never lock. "Create Order"
opens the new-order form via `?from_quote=ID`. Order lines record `quote_product_id` / `pricing_rule_id`.
An accepted lock can be ended early (`Quote#end_lock!` → `lock_ended_on`; `expiry_date` stays as quoted).
**Price check**: PDI-imported order lines keep PDI's price (PDI bills). `PriceCheckService` runs on
import and stores `expected_price` (lock on the order date, else rule) + `price_check`
(match / lock_mismatch / rule_mismatch / no_price); mismatches on unbilled orders list at /price_exceptions.
**ProductionOrder** = STATUSES: pending / in_progress / completed
**WorkOrders / Jobs** = shop work orders with comments; Jobs + JobWorkers are line-worker clock-in/out (`/line`)
**User roles**: admin, worker (drivers), line_worker

---

## PDI integration (FTP)
PDI exchanges files with the app over FTP. All sync jobs include `PdiFtpConcern`,
download the file, delete it from FTP, run an import service, and record a `SyncLog`.

| Job | Import service | File |
|---|---|---|
| `PdiOrderSyncJob` | `CustomerOrderImportService` | `orders.xls` |
| `PdiVendorSyncJob` | `PdiVendorImportService` | AP Vendor List `.csv` |
| `PdiProductSyncJob` | `InventoryImportService` (maps PDI site codes → locations) | current inventory `.xls` |
| `PdiPurchaseOrderSyncJob` | `PdiWarehouseTransactionImportService` | Warehouse Transaction Report `.xls` |

- Outbound: `PdiExportJob` uploads a CSV to FTP when a PurchaseOrder transitions to `submitted`.
- **Scheduling**: `rake scheduler:tick` runs every minute as a Render cron job. It walks
  `AutomatedProcessesController::PROCESSES`, checks each `AutomatedProcessConfig` cron
  schedule, and runs due jobs with `perform_now`. Schedules are editable at `/automated_processes`.
- Manual imports (each with a preview step, and downloadable source file via SyncLog):
  customer orders, PDI products, PDI inventory, PDI purchase orders, purchase orders,
  repack batches, warehouse transactions, inventory, BOMs, min/max, vendor freight terms.
- Debug: `rake pdi:ftp_ls`, `rake pdi:sync_vendors`

---

## MRP / inventory / purchasing

### Models
- `Product` — is_raw_material, item_type, current_stock, reorder_point, safety_stock, cost_per_unit,
  standard_cost (history in `StandardCostHistory`), pdi_tank_id, stock_status, available_stock
- `ProductComponent` — BOM lines
- `LocationProduct` — per-location stock (`quantity`); `LocationProduct.adjust!(location, product, qty)`
- `PurchaseOrder` — lifecycle: draft → pending_approval → approved → submitted → received → cancelled;
  `pdi_reference` (shown via `display_number`), `posted_at`, optional `location_id`
- `InventoryTransaction` — polymorphic audit trail (direction: 'in'/'out'), optional `location_id`
- `ProductionOrderBatch` — QC workflow: qc_status (pending/passed/hold/rejected), lot_number, complete_and_deduct_inventory!(user)
- `ProductionOrderComponent` — belongs_to :product (optional), quantity_actual
- `PricingRule` / `PricingRuleProduct` — pricing rules that auto-populate prices on customer orders

### Services (app/services/)
- `MrpEngine` — raw material requirements from open customer orders + BOM
- `BomPopulatorService` — auto-populates production order components from product BOM
- `MaterialAvailabilityService` — checks if raw materials are available for a production order
- `ReorderService` — creates draft POs for products below reorder_point
- `PricingRuleService.lookup(customer, product)` — resolves the applicable pricing rule
- `InventoryIntelligenceService` — daily/weekly inventory report emails (`InventoryIntelligenceJob`)
- `*ImportService` — one per import type (see PDI section)

### Key workflows
1. **Batch completion**: production order show page → QC panel → 'passed' → "Complete Batch & Update Inventory" → `batch.complete_and_deduct_inventory!(current_user)`
2. **Auto-reorder**: `ReorderCheckJob` → `ReorderService.run` → draft POs → emails admins with email_opt_in
3. **PO receiving** is two steps: `mark_received!(user)` only sets status; `post_to_inventory!(user)`
   creates InventoryTransactions and adjusts stock (LocationProduct if the PO has a location,
   otherwise `Product#current_stock`), then sets `posted_at`. Idempotent via `posted?`.
4. **Manual adjustment**: /inventory_adjustments/new → InventoryTransaction + stock adjustment

### Notable routes
- /mrp, /purchasing_report, /inventory_intelligence, /inventory_transactions, /inventory_adjustments/new
- /purchase_orders (+ approve / submit / receive / post_to_inventory, export_pdi, dashboard)
- /production_orders (kanban, dashboard, bom_cost_report)
- /customer_orders (dashboard, bulk_close), /dispatches/kanban, /warehouse/kanban
- /pricing_rules, /automated_processes, /docs (in-app user guides + changelog)
- Products, Customers, Vendors, Locations all support CSV export → import_csv → process_import → confirm_import

---

## Map
- Leaflet.js + OpenStreetMap tiles, centered on Georgia
- Location markers: blue=origin terminal, red=destination, green=has active order
- Dispatch routes: colored lines by days until dispatch_date (green/yellow/orange/red)
- OSRM routing loaded async after page paint (fetch /locations/dispatch_routes)
- Samsara GPS trucks loaded async after page paint (fetch /locations/vehicles)
- Both async endpoints live in LocationsController

---

## Environment variables
- `DATABASE_URL`, `RAILS_MASTER_KEY`
- `SAMSARA_API_KEY` — live truck tracking
- `TURNSTILE_SITE_KEY`, `TURNSTILE_SECRET_KEY` — registration captcha (also readable from credentials)
- `PDI_FTP_HOST`, `PDI_FTP_USER`, `PDI_FTP_PASSWORD` (+ optional `PDI_FTP_ORDER_DIR`,
  `PDI_FTP_VENDOR_DIR`, `PDI_FTP_PRODUCT_DIR`, `PDI_FTP_PO_DIR`, `PDI_FTP_PATH`)
- `SENDGRID_USERNAME`, `SENDGRID_PASSWORD`
- `TWILIO_SID`, `TWILIO_TOKEN`, `TWILIO_NUMBER`
- `BATCH_QR_PASSWORD`, `BATCH_QR_SECRET` — batch label/QR gate (/gate, /labels, /l)
- `EXECJS_RUNTIME=Node` on Render (prevents Bun conflict)

## Render production notes
- db:migrate runs automatically on deploy
- Seeds are guarded: `return if Rails.env.production?`
- Cron job runs `rake scheduler:tick` every minute

---

## Tests
Minitest under `test/`. Coverage is concentrated on MRP services/models
(MrpEngine, BomPopulator, MaterialAvailability, Reorder, ProductionOrderBatch);
the PDI sync/import code is largely untested.

---

## Roadmap / known issues

### High priority remaining
- Cycle counts / physical inventory reconciliation
- Partial PO receiving (currently all-or-nothing)
- Finish multi-location inventory (LocationProduct exists; stock falls back to global `current_stock` when no location)
- Production order completion UI improvements

### Known issues / notes
- `dispatch_customer_orders` join table is legacy but still used by `CustomerOrder.unassigned_open_orders`
- With the :async adapter, failed jobs are only visible in `SyncLog` and the Rails log
- Zone.Identifier files from Windows show as deleted in git status — safe to ignore
