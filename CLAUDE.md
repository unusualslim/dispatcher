# LoadNTrucks — Claude Code Context

## What this app is
Ruby on Rails 7.0.8 + PostgreSQL app for **Perry Brothers Oil** (Five Points Service),
Americus/Albany GA area. Manages petroleum product dispatch, customer orders,
driver/truck tracking, vendor management, location/terminal management, and
production orders (DEF manufacturing). Live at **loadntrucks.com**, hosted on Render.

Primary contact: John (admin@perrybrothersoil.com)

---

## Stack
- Ruby 3.1.2, Rails 7.0.8, PostgreSQL 15
- Bootstrap 5, Leaflet.js (maps), Select2, FullCalendar
- jsbundling-rails (esbuild) + cssbundling-rails (sass via yarn)
- Devise authentication + reCAPTCHA
- Samsara Fleet API for live GPS truck tracking
- Render for production hosting (uses DATABASE_URL env var)
- SendGrid for email (ActionMailer configured in production)
- Active Job with default :async adapter (no Sidekiq)

---

## Local dev setup (Windows 10)
- PostgreSQL 15 on port **5433** (trust auth), PG14 on 5432 — always use 5433
- config/database.yml is gitignored — local settings: host: 127.0.0.1, port: 5433, username: postgres
- `.env` is gitignored — contains RECAPTCHA keys and SAMSARA_API_KEY
- Run server: `bundle exec rails server`
- Assets: `yarn build && yarn build:css` if assets are missing
- Windows quirks: Puma workers disabled (Gem.win_platform? guard in config/puma.rb),
  Sprockets uses MemoryStore cache (config/environments/development.rb)

---

## Key domain concepts

**Locations** = terminals (origin, category_id: 1) or customer delivery sites (destination, category_id: 2)
**Dispatches** = a driver assignment linking an origin terminal to customer orders. Status: "Sent to Driver" shows on map.
**CustomerOrder** = order_status enum values: "New" (open), "complete" (done), "on_hold", "Deleted"
**ProductionOrder** = STATUSES: pending / in_progress / completed
**User roles**: admin, worker (drivers show up in users list)

---

## MRP System (built April 2026)

Full MRP module added directly to the app. Key files:

### Models
- `Product` — is_raw_material, current_stock, reorder_point, safety_stock, cost_per_unit, stock_status, available_stock
- `PurchaseOrder` — lifecycle: draft → pending_approval → approved → submitted → received → cancelled
- `InventoryTransaction` — polymorphic audit trail (direction: 'in'/'out')
- `ProductionOrderBatch` — QC workflow: qc_status (pending/passed/hold/rejected), lot_number, complete_and_deduct_inventory!(user)
- `ProductionOrderComponent` — belongs_to :product (optional), quantity_actual

### Services (app/services/)
- `MrpEngine` — calculates raw material requirements from open customer orders + BOM
- `BomPopulatorService` — auto-populates production order components from product BOM
- `MaterialAvailabilityService` — checks if raw materials are available for a production order
- `ReorderService` — creates draft POs for products below reorder_point

### Key workflows
1. **Batch completion**: production order show page → QC panel → set status to 'passed' → "Complete Batch & Update Inventory" → calls batch.complete_and_deduct_inventory!(current_user) → deducts raw materials, adds finished goods
2. **Auto-reorder**: ReorderCheckJob.perform_later → ReorderService.run → creates draft POs → emails admins with email_opt_in
3. **PO receiving**: PurchaseOrder#mark_received!(user) → creates InventoryTransaction + increments current_stock
4. **Manual adjustment**: /inventory_adjustments/new → creates InventoryTransaction + adjusts stock

### Routes added
- GET  /mrp                              → mrp#index (dashboard)
- GET  /purchase_orders                  → purchase orders list
- GET  /inventory_transactions           → audit trail
- GET  /inventory_adjustments/new        → manual stock adjustment
- PATCH /production_order_batches/:id/update_qc
- PATCH /production_order_batches/:id/complete

---

## Map
- Leaflet.js + OpenStreetMap tiles, centered on Georgia
- Location markers: blue=origin terminal, red=destination, green=has active order
- Dispatch routes: colored lines by days until dispatch_date (green/yellow/orange/red)
- OSRM routing loaded async after page paint (fetch /locations/dispatch_routes)
- Samsara GPS trucks loaded async after page paint (fetch /locations/vehicles)
- Both async endpoints live in LocationsController

---

## Render production notes
- DATABASE_URL env var used (no database.yml in repo)
- SAMSARA_API_KEY env var required for live truck tracking
- EXECJS_RUNTIME=Node env var required (prevents Bun conflict)
- RECAPTCHA_SITE_KEY and RECAPTCHA_SECRET_KEY env vars required
- db:migrate runs automatically on deploy
- Seeds are guarded: `return if Rails.env.production?`

---

## What's working, what's next

### Done
- Full dispatch/order/driver workflow
- MRP: BOM, production orders, batch QC, inventory tracking, purchase orders, reorder automation
- Live GPS map with Samsara integration
- Inventory adjustment UI + transaction history
- Reorder notification emails

### High priority remaining
- Cycle counts / physical inventory reconciliation
- Partial PO receiving (currently all-or-nothing)
- Multi-location inventory (stock is global per product, not per tank/terminal)
- Production order completion UI improvements

### Known issues / notes
- dispatch_customer_orders join table still exists in schema but is legacy
- Zone.Identifier files from Windows show as deleted in git status — safe to ignore
