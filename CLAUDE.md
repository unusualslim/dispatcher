# FPS Team (formerly LoadNTrucks) — Claude Code Context

## What this app is
Ruby on Rails 7.2 + PostgreSQL app for **Perry Brothers Oil** (Five Points Service),
Americus/Albany GA area. Manages petroleum product dispatch, customer orders,
driver/truck tracking, vendor management, location/terminal management, production
orders (DEF manufacturing), MRP/inventory, purchasing, and pricing. Integrates with
**PDI** (the ERP/accounting system) via FTP file exchange. Live at **team.fivepointsservice.com**
(loadntrucks.com still allowed: printed QR batch labels embed it), hosted on Render (`dispatcher2.onrender.com`).
Production hostnames are allow-listed in `config.hosts` (production.rb). Mail sends from
`no-reply@fivepointsservice.com`. PDI file names still say "LoadNTrucks" — leave those patterns alone.
Sidebar uses the fivepointsservice.com palette (warm black, FPS orange) — see the `--sidebar-*` vars in custom.css.

Primary contact: John (admin@perrybrothersoil.com)

---

## Stack
- Ruby 3.4.11, Rails 7.2 (`config.load_defaults 7.0` — newer framework defaults not yet enabled), PostgreSQL 15, Puma 7
- Bootstrap 5 + jQuery + Select2 + FullCalendar 5 (all from CDN in the layout), Leaflet.js (maps)
- jsbundling-rails (esbuild) + cssbundling-rails (sass via yarn); Turbo 7, Trix 2.1 / Action Text
- Devise authentication. Sign-up (`/users/sign_up`) is **admin-only** — it's how admins add users
  (Users → New user), with **Cloudflare Turnstile**. Users can't change their own role (only admins, on /users).
- Active Storage: **DigitalOcean Space `loadntrucks` (nyc3)** in production (`:digitalocean` in storage.yml,
  keys from env); local disk in dev/test. Action Text rich text on Location notes and Announcements.
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
- Ruby version comes from `.ruby-version` (**3.4.11**; the Gemfile reads it) — make sure rbenv has it installed
- **libvips is required** (`brew install vips`): Rails 7.2's Active Storage loads ruby-vips at boot and
  refuses to start without libvips >= 8.13 (Render's Debian 12 image ships it)
- Tests use the `:test` Active Job adapter; jobs are enqueued, not run
- Windows quirks (from earlier dev on Windows 10): Puma workers/threads limited via
  `Gem.win_platform?` guard in config/puma.rb; Sprockets uses MemoryStore cache in
  config/environments/development.rb. On Windows, PG15 was on port 5433.

---

## Navigation (sidebar)
- `app/views/layouts/_sidebar.html.erb`: admins get collapsible groups Sales / Dispatch / Production /
  Purchasing / Inventory / Admin (each group's dashboard is its first link); drivers and line workers
  get short navs. Open/closed state is remembered per browser (localStorage).
- Links use the `nav_item(label, path, icon, active:, keywords:)` helper; `keywords` feed the quick-jump
  search box (press `/`). `nav_search_item` adds search-only entries (used for each importer).
- All manual importers are listed once in `ImportsController::IMPORTS` (hub at `/imports`, Admin → Data Imports);
  add new importers there.
- Styling: `--sidebar-*` variables and group/link rules in `app/assets/stylesheets/custom.css`.

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
**Quote Margin Review** (`QuoteMarginReview`, /quote_margin_review, /quotes/:id/margin_review): locked
price vs today's cost on the line's basis since `quote_products.priced_at`; Re-price when margin falls
below the floor (rule target, or the quoted margin if negotiated below target). Drivers come from
StandardCostHistory, `InventoryCostHistory` (recorded on every `cost_per_unit` change), and BOM
component history. "Re-quote" (`Quote#create_requote!`) drafts a quote at today's rule prices.
**ProductionOrder** = STATUSES: created (planned, nothing done) / in_progress (set automatically by the first /line
clock-in) / completed (stamps `date_completed`); `OPEN_STATUSES` = created + in_progress. The production order *is* the batch.
**Production costing / GL**: BOM = inventory components (`ProductComponent`, moved by PDI repack) + non-inventory
`ProductCostLine`s (qty × unit cost ÷ per; labor lines use the `AppSetting.labor_rate`, "per" = units per worker-hour).
"Standard Calculated (BOM)" pricing uses this full cost. PDI's single per-product repack fee (`products.pdi_repack_fee`)
goes to a clearing account; `ProductionOrderJournal` builds the FPST GL entry per production order (Dr clearing,
Cr cost lines at standard, Cr /line labor at actual split by `users.employment_type`, variance plug), shown on the
order's GL Posting tab. **Ledger**: `LedgerEntry`/`LedgerLine` freeze posted entries (corrections = reversing
entries, `<ref>-REV`, re-post `<PO#>-2`). `ProductionGlPosting` auto-posts on completion (for orders completed on/after the
`gl_posting_start_date` setting; reopening reverses). Costing always posts; `reporting_groups.post_inventory_gl` is
reserved for the app taking over a category's inventory/COGS/sales posting from PDI (not built); the scheduled `PdiGlExportJob` sweeps ready orders and `PdiGlExport` uploads pending entries as one FPST CSV
(no header row) over FTP, marking them exported. Production → GL Ledger lists entries. `PdiGlImport` = PDI's 13-column GL import layout.
Accounts post as Site-Major-Sub (site = `Location#pdi_site_code`, 4 digits). **ReportingGroup** uses PDI item types:
fuel/warehouse groups = PDI product categories (linked by `products.category` name, auto-created); non_inventory
groups (Consumables, Labor, Overhead) hold cost lines. Admin → Reporting Groups / Costing Settings.
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
- `TWILIO_SID`, `TWILIO_TOKEN`, `TWILIO_NUMBER` (MessagesController reads Twilio creds from Rails credentials)
- `BATCH_QR_PASSWORD`, `BATCH_QR_SECRET` — batch label/QR gate (/gate, /labels, /l)
- `DO_SPACES_KEY`, `DO_SPACES_SECRET` — Active Storage on the DigitalOcean Space (key needs read/write/delete)
- `HOSTNAME=team.fivepointsservice.com` — host for links in emails. Keep it set explicitly (Linux may set its own HOSTNAME)
- `WEB_CONCURRENCY=0` — Puma single mode (cluster with 1 worker only wastes memory)
- `EXECJS_RUNTIME=Node` on Render (prevents Bun conflict)

## Render / hosting notes
- Two services deploy from `main`: web **Dispatcher** (`srv-cloa2b0gqk6s73860dmg`, build `bin/render-build.sh`)
  and cron **Automated Processes Scheduler** (`crn-d8u1kjbtqb8s73anodag`, `rake scheduler:tick` every minute;
  its build command is set in the Render dashboard). The Render CLI is installed (workspace "PerryBrothers").
- db:migrate runs automatically on deploy (web build). Seeds are guarded: `return if Rails.env.production?`
- Cloudflare proxies both domains (same account). loadntrucks.com → team.fivepointsservice.com is a
  Cloudflare Single Redirect in the **loadntrucks.com** zone (path + query preserved for QR labels).
- production.rb: `force_ssl` (HSTS, secure cookies) and the `config.hosts` allowlist both skip requests
  without `X-Forwarded-Proto` — that's Render's internal health check (`HEAD /`).
- Render's image provides libvips 8.14 (Debian 12); Rails 7.2.4 needs >= 8.13 and ruby-vips >= 2.2.1 to boot.

---

## Tests
Minitest under `test/`. Coverage is concentrated on MRP services/models
(MrpEngine, BomPopulator, MaterialAvailability, Reorder, ProductionOrderBatch);
the PDI sync/import code and most controllers are largely untested. Security regression tests live in
`test/integration/` (admin-only sign-up, Twilio webhook signature, announcement rich text).
The suite has **~35 pre-existing failures/errors** (unauthenticated scaffold controller tests, MRP tests
using old statuses, order-dependent data) — compare failures against that baseline rather than expecting green.
CI (`.github/workflows/lint.yml`) runs RuboCop only.

## Lint
`bin/rubocop` (rubocop + rubocop-rails, config in `.rubocop.yml`). Existing offenses are
baselined per file in `.rubocop_todo.yml`; new code should pass clean. After cleaning up a
file, remove it from the todo (or regenerate with the command at the top of `.rubocop.yml`).

---

## Roadmap / known issues

### High priority remaining
- Cycle counts / physical inventory reconciliation
- Partial PO receiving (currently all-or-nothing)
- Finish multi-location inventory (LocationProduct exists; stock falls back to global `current_stock` when no location)
- Production order completion UI improvements

### Upgrades / security still open (as of Oct 2026)
- **Rails 8.1** — Brakeman flags Rails 7.2's security support as ended (2026-08-09)
- Turbo 7 → 8 (navigation behavior changes), Devise 5, rubyzip 3 (needs `roo` + `roo-xls` upgraded together)
- Build-tool npm alerts via Dependabot yarn PRs (skip `@rails/actiontext` 8.x while on Rails 7.2)
- Flip `load_defaults` stepwise; Rack `:unprocessable_entity` → `:unprocessable_content`

### Known issues / notes
- `Dispatch#dispatch_status` is a declared, non-persisted attribute (the real column is `status`), but the
  dispatch show page and production dashboard still read it — those status badges never match saved records
- The Twilio number is shared with other apps and has no inbound webhook, so `/messages/reply` is unused
  (it rejects requests without a valid `X-Twilio-Signature`)
- `app/assets/javascript/custom.js` page-specific scripts throw null `addEventListener` errors on other pages (harmless)
- `dispatch_customer_orders` join table is legacy but still used by `CustomerOrder.unassigned_open_orders`
- With the :async adapter, failed jobs are only visible in `SyncLog` and the Rails log
- Zone.Identifier files from Windows show as deleted in git status — safe to ignore
