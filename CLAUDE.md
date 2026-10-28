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
- `app/views/layouts/_sidebar.html.erb`: collapsible groups Sales / Dispatch / Production /
  Purchasing / Inventory / Accounting / Admin (staff see the areas they can view; Admin group is admin-only) (each group's dashboard is its first link); drivers and line workers
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
Cancelled as Order/Quote, Quarantine, Credited, Staged, Loaded — key `truck_loaded`). "Open" work = `CustomerOrder::ACTIVE_STATUSES`.
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
clock-in) / quality_check (assigns `lot_number`; results recorded against the product's `QualitySpec`s — numeric
min/max or pass/fail, method, "< 0.5" qualifiers; out-of-range allowed, reviewed at /quality_exceptions; printable
certificate at /production_orders/:id/quality_certificate) / completed (needs all checks + total_qty_produced; stamps
`date_completed`; `ProductionOrderInventory` consumes components and adds finished goods, reversed on reopen) / voided (admin-only `ProductionOrderVoid`: reverses batch inventory
moves and any posted GL entry, clocks out crews; voided orders are read-only); `OPEN_STATUSES` = created + in_progress. The production order *is* the batch.
**Production costing / GL**: BOM = inventory components (`ProductComponent`, moved by PDI repack) + non-inventory
`ProductCostLine`s (qty × unit cost ÷ per; labor lines use the `AppSetting.labor_rate`, "per" = units per worker-hour).
"Standard Calculated (BOM)" pricing uses this full cost. PDI's single per-product repack fee (`products.pdi_repack_fee`)
goes to a clearing account; `ProductionOrderJournal` builds the FPST GL entry per production order (Dr clearing,
Cr cost lines at standard, Cr /line labor at actual split by `users.employment_type`, variance plug), shown on the
order's GL Posting tab. **Cost Items** (`CostItem`, Accounting → Cost Items): catalog of non-inventory costs (pallets, film,
tape, labels, labor, overhead) priced as bought (each/roll/gallon/day); a `ProductCostLine` with `cost_item_id` takes the
item's group, name and current unit cost (labor lines still use the labor rate). Loaded 2026-10-27 from the internal
"MASTER PRICING MATRIX" workbook, whose Master Item-Price sheet also set 48 component standard costs (landed, effective
2026-10-01; migration `LoadStandardCostMatrix`). Its kit tabs (one block per package type: 1/2.5 squat, 55 gal drum…)
became cost lines on 216 finished goods (`LoadKitCostLines`: template → products by BOM packaging/family; labor =
hours at the labor rate sized to the sheet's $/unit). **Ledger**: `LedgerEntry`/`LedgerLine` freeze posted entries (corrections = reversing
entries, `<ref>-REV`, re-post `<PO#>-2`). `ProductionGlPosting` auto-posts on completion (for orders completed on/after the
`gl_posting_start_date` setting; reopening reverses). Costing always posts; `reporting_groups.post_inventory_gl` is
reserved for the app taking over a category's inventory/COGS/sales posting from PDI (not built); the scheduled `PdiGlExportJob` sweeps ready orders and `PdiGlExport` uploads pending entries as one FPST CSV
(no header row) over FTP, marking them exported. Production → GL Ledger lists entries. `PdiGlImport` = PDI's 13-column GL import layout.
Accounts post as Site-Major-Sub (site = `Location#pdi_site_code`, 4 digits). **ReportingGroup** uses PDI item types:
fuel/warehouse groups = PDI product categories (linked by `products.category` name, auto-created); non_inventory
groups (Consumables, Labor, Overhead) hold cost lines. Admin → Reporting Groups / Costing Settings.
**WorkOrders / Jobs** = shop work orders with comments; Jobs + JobWorkers are line-worker clock-in/out (`/line`)
**User roles**: admin (everything), staff (per-area levels), worker (drivers), line_worker. Users with history can't be
deleted (`User#history_reasons`); admins deactivate them instead (`deactivated_at`: can't sign in, `User.active` in pickers). Staff `users.permissions`
jsonb = { area => view|edit|approve } for sales/dispatch/production/purchasing/inventory/accounting (`UserPermissions`).
Controllers declare `permission_area :x, approve: [...], lookups: [...]`: GET needs view, writes edit, listed actions
approve, destroy* always admin. Views use `can?(:area, :level)`. Admin-only pages keep `require_admin!`.

---

## PDI integration (FTP)
PDI exchanges files with the app over FTP. All sync jobs include `PdiFtpConcern`,
download the file, delete it from FTP, run an import service, and record a `SyncLog`.

| Job | Import service | File |
|---|---|---|
| `PdiOrderSyncJob` | `CustomerOrderImportService` | `orders.xls` (daily): the PDI Order API Sync (below) owns orders since 2026-10-26, so for orders already in the app this only fills **invoice date, invoice # and salesperson** (the API doesn't send them); orders not in the app (history) are created |
| `PdiVendorSyncJob` | `PdiVendorImportService` | AP Vendor List `.csv` |
| `PdiProductSyncJob` | `InventoryImportService` (maps PDI site codes → locations) | current inventory `.xls` |
| `PdiPurchaseOrderSyncJob` | `PdiWarehouseTransactionImportService` | Warehouse Transaction Report `.xls` |
| `PdiFuelInventorySyncJob` | `PdiInventoryImportService` (FI report: tanks by product + PDI site number) | FI Inventory Report `.xls` |

- Outbound: `PdiExportJob` uploads a CSV to FTP when a PurchaseOrder transitions to `submitted`;
  `PdiGlExportJob` (scheduled) posts ready production journals and uploads pending FPST GL entries (`PdiGlExport`).
- Vendors are keyed by PDI vendor ID; names are **not** unique (PDI has same-name vendors, e.g. KM Solutions 1570
  product / 1571 freight), so pickers show `Vendor#label` ("Name (ID)"). Never match vendors by name.
- `PdiProductSyncJob`'s file pattern skips the FI report (that's `PdiFuelInventorySyncJob`).
- **Scheduling**: `rake scheduler:tick` runs every minute as a Render cron job. It walks
  `AutomatedProcessesController::PROCESSES`, checks each `AutomatedProcessConfig` cron
  schedule, and runs due jobs with `perform_now`. Schedules are editable at `/automated_processes`.
  A new process starts at its `default_schedule` (blank = Off), else hourly (`config_for`).
- **Invoice dates**: the API sends none. `PdiInvoiceDateImportService` (Data Imports → PDI Invoice Dates) takes a CSV from
  the user's PDI SQL query (columns found by header: order number, invoice date, optional invoice # / salesperson) and
  bulk-updates orders by `external_order_no`. Big `orders.xls` files time out (Cloudflare ~100s, roo memory), so this is
  the route for history.
- Manual imports (each with a preview step, and downloadable source file via SyncLog):
  customer orders, PDI products, PDI inventory, PDI purchase orders, purchase orders,
  repack batches, warehouse transactions, inventory, BOMs, min/max, vendor freight terms.
- Debug: `rake pdi:ftp_ls`, `rake pdi:sync_vendors`

## PDI Enterprise Web Service (SOAP)
`PdiWebService` calls https://account.fivepointsservice.com/PDIEnterpriseWeb.asmx (partner `team.fivepoints`,
UserCredentials header). Results are XML; PDI errors arrive as `PDIExceptionMessage` (HTTP 200) or SOAP faults.
- Working: `GetMasterData` (~4.6 MB, mode ignored), `CustomerCreditCheck` (CreditStatus 0 = OK, 1 = Credit Hold),
  `GetOrderStatus` (numeric; 1 = Open, 99 = unknown order).
- PDI's XSDs are in `docs/pdi_api/` (status codes: `PDIOrderElementTypes.xsd` → `PdiOrders::Statuses`).
- `GetFuelOrders`/`GetWarehouseOrders` (`PdiWebService::OrderFilter`, sent with `xmlns=""`): `RecordsToInclude`
  0/1/2 (new / new+changed / changed) only return orders not yet sent to the web partner and mark them sent (PDI
  can't reset the flags); **3 = all matching records**, which the sync always uses.
- **PDI Order API Sync** (`PdiOrderApiSyncJob`, every 15 min in production; the order source since 2026-10-26):
  `PdiOrders::Feed` fetches every run (warehouse one status per call since its orders carry no status; finished
  statuses only for delivery dates in the last 60 days) → raw XML saved gzipped on the SyncLog → `PdiOrderApiImportService`
  upserts by `external_order_no` (`OrderWriter`, `Destination` matches PDI customer/ship-to IDs; DestinationType 0 =
  own site, no customer) → `StatusCheck` asks `GetOrderStatus` for open app orders PDI didn't send (200/run).
  Re-import a saved feed: `rake pdi:reimport_orders[SYNC_LOG_ID]`. Imported lines may have negative prices (credits).
  Fuel lines use the loaded product (`PurchasedProductID`; ordered 10011219 Bulk DEF → 901) except blends. Line
  `item_type` comes from `Product#order_item_type`: fuel / non-inventory groups, groups ticked **Buy** on Reporting
  Groups (HYDRAULICS) and raw materials are "buy".
- **PDI Master Data** (`PdiMasterDataImportService` + `app/services/pdi_master_data/*_sync.rb`; Data Imports page and
  `PdiMasterDataSyncJob`, schedule Off until set): customers → `customers.pdi_customer_id`; ship-tos (per customer in
  PDI) → `customer_locations.pdi_location_id`, so one app location can serve many customers' ship-tos; terminals →
  `locations.pdi_terminal_id` (link only); fuel + warehouse products by ID. Existing locations are never renamed.
  PDI's Active / AccountStatus sets `products.active` / `customers.active` (an inactive record only gets the flag;
  inactive customers' ship-tos are skipped). Inactive records leave pickers (`Product.active`, `.selectable(keep_ids)`
  keeps a record's current choice) and the index pages unless "Show inactive" is ticked.
- **Admin → Merge Customers** (`CustomerMerge`): folds app customers the import couldn't match by name into their
  PDI twin (orders, quotes, rules, locations…); store-numbered locations ("146 Cartersville TA", "35 - Name") fold
  into the PDI ship-to of that number. **Admin → Merge Locations** (`LocationMerge`, also "Merge into…" on a
  location page): one location into another, moving every reference, combining stock and carrying PDI links;
  refuses two different PDI ship-tos of one customer.
- The FTP order import prefers these IDs ("2362 - Name" / "12 - Name" prefixes) before matching by name.
- Customer and open-order pages lazy-load PDI credit (`/customers/:id/pdi_credit`, Turbo Frame).

---

## MRP / inventory / purchasing

### Models
- `Product` — is_raw_material, item_type, current_stock, reorder_point, safety_stock, cost_per_unit,
  standard_cost (history in `StandardCostHistory`), pdi_tank_id, stock_status, available_stock
- `ProductComponent` — BOM lines
- `LocationProduct` — per-location stock (`quantity`); `LocationProduct.adjust!(location, product, qty)`
- `PurchaseOrder` — lifecycle: draft → pending_approval → approved → submitted → received → cancelled; admins can
  void (`PurchaseOrderVoid`: reverses posted receipts via `InventoryReversal`, read-only after, voided status);
  `pdi_reference` (shown via `display_number`), `posted_at`, optional `location_id`
- `InventoryTransaction` — polymorphic audit trail (direction: 'in'/'out'), `location_id`; costed rows carry
  `movement_type` (opening/receipt/sale/production_use/production_output/adjustment/pdi_sync/revaluation),
  `occurred_on`, `unit_cost`, `total_cost`, `variance_amount` (PPV on standard receipts) and the location's balance after.
  Rows from before costing have no type or cost.
- `ProductionOrderBatch` — now just the PDI batch number(s) recorded on an order (its old per-batch QC/complete
  is retired; QC and inventory moves happen on the production order)
- `QualitySpec` / `QualityResult` — per-product quality checks and each order's recorded results
- `ProductionOrderComponent` — belongs_to :product (optional), quantity_actual
- `PricingRule` / `PricingRuleProduct` — pricing rules that auto-populate prices on customer orders

### Costed inventory (since 2026-10-27)
- Each fuel/warehouse `ReportingGroup` has a `costing_method`: weighted_average (default, PDI's), standard
  (`products.standard_cost`; receipt actual − standard → `variance_amount`) or fifo (`InventoryCostLayer`s, issues record
  `InventoryLayerDraw`s). Cost is kept **per location** (`location_products.inventory_value`).
- **Every stock change goes through `InventoryPosting`** (`post!` signed quantity, `reverse!` at the original value,
  `revalue!` value-only). No location → main warehouse (PDI site 0002). Don't write `LocationProduct.quantity` directly
  (only the retired per-batch completion still uses `LocationProduct.adjust!`).
- Movements: PO post_to_inventory (receipt at line cost), production (components out at cost; output in at components +
  `ProductionOrderCosting#absorbed_cost`), adjustments (optional unit cost), voids/reopens (`InventoryReversal`), PDI
  inventory imports (FI + warehouse: post only the difference as `pdi_sync`), and **sales**: `InventorySales.sync!` runs
  on every PDI order write — shipped statuses (shipped … billed, delivered, credited) take `shipped_quantity` (PDI lifted /
  invoiced / picked; falls back to ordered) out of the line's warehouse, re-posting when lines change or the order cancels.
  Dropship and non-inventory lines are skipped.
- `InventoryRevaluation`: one-time `opening!` (admin button on /inventory_valuation; sets AppSetting
  `inventory_tracking_start_date`; sales before it are ignored), revalues on standard-cost change and method change.
- /inventory_valuation (`InventoryValuation`): value as of a date (today's balance minus later movements), movements
  by type, PPV, PDI sync differences (how much movement the app missed).
- **PDI Purchase Orders import** (`PdiPurchaseOrderImportService`, manual on Data Imports for now — the user is working on
  automating the PDI SQL export): 56-column CSV, no header, one row per PO line (col 0 PDI PO key, 1 PO number, 7/34
  site, 9 status). Matches on `purchase_orders.pdi_po_key`, else (POs imported before keys) PO number. `pdi_reference` is not
  unique (PDI numbers repeat: "TODD"…); numberless POs received before tracking aren't re-imported. Refreshes PDI POs not yet posted;
  Invoiced/Inventoried POs received on/after the inventory start date at one of our warehouses post receipts at line
  cost, older/dropship ones are only stamped `posted_at`. POs with no warehouse (dropship 7777/1331) can't be posted to
  inventory, and PDI-imported POs are never sent back to PDI by `PdiExportJob`.
- **Inventory GL** (`InventoryGlPosting` + `InventoryJournal`, run by the scheduled `PdiGlExportJob`): for groups with
  `post_inventory_gl`, receipts (Dr Inventory at book, Dr/Cr PPV, Cr received-not-invoiced at actual), sales (Dr COGS),
  adjustments + PDI syncs (vs inventory adjustments) and revaluations post as FPST entries, **one per source document
  and date** (reference = PO / PDI order / ADJ-… number, `-2`… when it posts again). Accounts are the group's six
  `*_gl_account` columns (Major-Sub, site from the location). Movements wait (listed on GL Ledger) while an account or
  site code is missing; `gl_posted_at` marks them done. Production moves stay on the production journal. Only movements
  on/after both the inventory start date and `gl_posting_start_date` post.

### Services (app/services/)
- `Mrp::Plan` (app/services/mrp/, page /mrp) — time-phased MRP **per warehouse**: per planned product
  (warehouse items, raw materials and anything in their BOMs; not fuel) and warehouse it projects stock day by day
  (`LocationProduct` on hand + open POs + open production − open customer order lines (not quotes/pending/
  released for billing/dropship sites 7777, 1331 Atmus) − production components), finds when it runs out / drops below safety
  stock (held at the product's main warehouse) and which orders cause it, then suggests a transfer of another
  warehouse's spare stock (`Mrp::Transfers`), then orders (need date − lead time) or production (− production
  days, passing component demand down at the same warehouse). POs / production orders / order lines with no
  warehouse are listed as "Needs a warehouse", not netted. Order lines get their warehouse from the PDI order
  sync (`customer_order_products.warehouse` = PDI site, `location_id` = location with that `pdi_site_code`; fuel
  lines not yet on a load = main warehouse 0002). Orders entered in the app use `customer_orders.ship_from_location_id`
  ("Ship from" on the order form). PDI is meant to be the order source; app-entered orders don't get PDI status.
  An app order linked to a PDI order by its number in the notes (`OD-051224-26`) is merged into the synced PDI order
  after each order sync (`PdiOrders::LinkedOrderMerge`: dispatches, equipment, quotes and notes move; app order deleted).
  Lead times: product → primary vendor → AppSetting `mrp_purchase_lead_days` (7); `products.production_days` →
  `mrp_production_days` (1); `mrp_transfer_days` (1); undated customer orders = order date +
  `customers.lead_time_days` → `mrp_customer_lead_days` (3). Defaults are editable on the MRP page. Lot-for-lot.
- `MaterialReadiness` — green/yellow/red dots for open production orders' components (and the order list) from
  the same events at the order's warehouse: in stock / depends on incoming supply / short.
- `BomPopulatorService` — auto-populates production order components from product BOM
- `MaterialAvailabilityService` — checks if raw materials are available for a production order
- `ReorderService` — creates draft POs for products below reorder_point
- `PricingRuleService.lookup(customer, product)` — resolves the applicable pricing rule
- `InventoryIntelligenceService` — daily/weekly inventory report emails (`InventoryIntelligenceJob`)
- `*ImportService` — one per import type (see PDI section)

### Key workflows
1. **Production completion**: In Progress → Send to Quality Check → record results → Mark Completed (inventory moves at
   completion). PDI batch numbers are still recorded on the order's edit form (the old per-batch QC/complete is retired).
2. **Auto-reorder**: `ReorderCheckJob` → `ReorderService.run` → draft POs → emails admins with email_opt_in
3. **PO receiving** is two steps: `mark_received!(user)` only sets status; `post_to_inventory!(user)`
   creates InventoryTransactions and adjusts stock (LocationProduct if the PO has a location,
   otherwise `Product#current_stock`), then sets `posted_at`. Idempotent via `posted?`.
4. **Manual adjustment**: /inventory_adjustments/new → InventoryTransaction + stock adjustment

### Notable routes
- /mrp, /purchasing_report, /inventory_intelligence, /inventory_transactions, /inventory_adjustments/new
- /purchase_orders (+ approve / submit / receive / post_to_inventory, export_pdi, dashboard)
- /production_orders (kanban, dashboard, bom_cost_report; member: void, record_quality, quality_certificate)
- /quality_exceptions, /ledger_entries (GL Ledger), /reporting_groups, /costing_settings
- /customer_orders (dashboard, bulk_close), /dispatches/kanban, /warehouse/kanban
- /pricing_rules, /automated_processes, /docs (in-app user guides + changelog)
- **/reports — Reports hub** (`ReportsController`, sidebar "Reports" at the top). Reports are classes in
  `app/services/reports/` (`Reports::Base`: `report title:, area:, description:, filters:`, `#columns`, `#rows` as hashes,
  optional `#link_for`; totals, CSV and print are shared). **Add new reports to `Reports::Registry::REPORTS`**; `PAGES`
  lists existing report-like pages on the hub. A report's `area` is the permission area that can see it. Filters
  (`Reports::Filters`): dates (default this month, `default_from` per report), customer, product, warehouse, vendor,
  item type, movement type, "problems only". Sales reports reuse `FinancialDashboard::Sales` (`Reports::SalesLines`).
- /financial_dashboard (Accounting, `FinancialDashboard` + `::Sales` / `::Operations` / `::Snapshot`): month to date vs the
  same days of the prior month and of last year. Sales = lines on orders by **invoice date** (from orders.xls; billed
  orders without one are flagged, not guessed), price × shipped qty, split by reporting group item type; taxes from PDI's
  per-line `tax_per_unit` (`price_includes_taxes` → taken out of product sales). Delivery = order date → invoice date.
- Products, Customers, Vendors, Locations all support CSV export → import_csv → process_import → confirm_import
- Products and Customers lists: filters/sorts live in `ProductListQuery` / `CustomerListQuery`; `sort_header` helper
  makes sortable column headers; `RemembersListFilters` keeps each user's last filters in `users.list_filters`
  (bare visit restores, the form sends `filtered=1`, Clear sends `reset=1`)

---

## Samsara routes
- **Send to Samsara** on a dispatch (`DispatchesController#send_to_samsara`, dispatch edit) → `Samsara::RoutePush` creates a
  Samsara route for the driver: home base → origin terminal (skipped when it's the home base) → customer stops (orders
  for the same site in a row = one stop) → home base. Notes from `Samsara::StopNotes` (load totals + dispatch notes on the
  terminal stop; order #, products, site phone/contacts/notes on each delivery stop; 2000-char cap).
- Times: only the first stop is real (dispatch date at AppSetting `samsara_route_start_time`, default 08:00 Eastern);
  later stops (the last one too: Samsara 400s without it) get placeholder arrivals and `recomputeScheduledTimes: true`
  lets Samsara fill them from drive time.
- Re-send PATCHes the stored `dispatches.samsara_route_id` (replacing all stops) unless the route has started; a route
  deleted in Samsara is recreated.
- Links (`Samsara::Links`): `users.samsara_driver_id` (matched by full name), `users.home_location_id` (else AppSetting
  `samsara_home_location_id`, else the origin), `locations.samsara_address_id` (`Samsara::AddressMatch`: street number +
  street in the same city, then GPS within 300 m, then normalized name; otherwise created in Samsara with a 250 m circle).
  Review on **Admin → Samsara** (`SamsaraSettingsController`).
- `Samsara::Client` wraps the API (`SAMSARA_API_KEY`). The token needs Read/Write Routes, Read Drivers and Read/Write
  Addresses for routing; the map's vehicle feed still has its own call in LocationsController.

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
- `PDI_API_PARTNER_ID`, `PDI_API_PASSWORD` (+ optional `PDI_API_URL`) — PDI Enterprise Web Service
- `PDI_FTP_HOST`, `PDI_FTP_USER`, `PDI_FTP_PASSWORD` (+ optional `PDI_FTP_ORDER_DIR`,
  `PDI_FTP_VENDOR_DIR`, `PDI_FTP_PRODUCT_DIR`, `PDI_FTP_PO_DIR`, `PDI_FTP_FUEL_DIR`, `PDI_FTP_GL_DIR`, `PDI_FTP_PATH`)
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
(Mrp::Plan, BomPopulator, MaterialAvailability, Reorder, ProductionOrderBatch);
the PDI sync/import code and most controllers are largely untested. Security regression tests live in
`test/integration/` (admin-only sign-up, Twilio webhook signature, announcement rich text, permissions).
Costing, ledger, quality checks, voids and permissions have their own model/service/integration tests.
The suite is **green** (cleared 2026-10-28); keep it that way. Controller tests sign in with
`Devise::Test::IntegrationHelpers` and create their own records rather than relying on fixtures.
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
- Production order export to PDI at completion (waiting on a PDI change so PDI's production order can link back
  to the app's; needs PDI's import layout)
- Real GL accounts (production has placeholders 8001-01…8006-01) and PDI FTP pickup of FPST files
- **Freight on purchases and sales** — bring freight into PO costs and customer order/sales pricing (design to come from the user)
- **Sales invoicing** — if the app controls inventory it needs a formal sales invoicing process; that role moves
  away from PDI (today PDI bills and the app only reads invoice dates/numbers back)
- **Standard cost exceptions** — an exceptions review like /quality_exceptions, for standard cost variances
- Hide Edit/Delete buttons for users without the level (the server already blocks them); finer per-view permissions
- Possibly: incoming supplier COAs on PO receipts; Void for dispatches/adjustments/quotes; lot traceability
  (fluid lot → bottle lot, entered by hand; PDI doesn't track lots)

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
- Render runs migrations before swapping instances, so renaming/dropping a live column causes ~30s of 500s on the
  old code — add the new column first and drop the old one in a later deploy
- Production orders and POs are voided (admin), not deleted; users with history are deactivated, not deleted
