# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Commands

**Start development server:**
```
bin/dev
```
This runs Foreman with `Procfile.dev`, starting Rails (port 3000), esbuild JS bundler, and PostCSS/Sass CSS watcher simultaneously.

**Run tests:**
```
bin/rails test                        # all tests
bin/rails test test/models/foo_test.rb  # single file
bin/rails test:system                 # Capybara/Selenium system tests
```

**Database:**
```
bin/rails db:prepare
```

**Assets (if needed outside bin/dev):**
```
yarn build          # JS with esbuild
yarn build:css      # CSS with PostCSS/autoprefixer
```

## Architecture

This is a **dispatch and logistics management system** for fuel delivery. Core workflow: customer orders are created for locations → grouped into dispatches → assigned to drivers with trucks → drivers are notified via Twilio SMS.

### Key Models & Relationships

- **Dispatch** — A truck delivery. Has many `CustomerOrder`s through `DispatchCustomerOrder` (join table). Belongs to a driver (`User`), `Vendor`, truck (`Thing`), trailer (`Thing`), and destination `Location`. Status enum: `new → sent_to_driver → complete → billed → deleted`.

- **CustomerOrder** — An order for product delivery to a location. Belongs to `Location` and optionally `Customer`. Has many `Product`s through `CustomerOrderProduct`. Can be marked `freight_only`. Status: `new → complete / on_hold / deleted`.

- **Location** — A delivery site (fueling station, warehouse, etc.). Has lat/lng for map display. Has rich text `dispatch_notes` and `location_notes` (ActionText). Has many `Customer`s through `CustomerLocation` and `Product`s through `LocationProduct`.

- **ProductionOrder** — Separate manufacturing workflow (pending → in_progress → completed). Has components (BOM) and batch tracking. Auto-generates a unique 6-char alphanumeric code.

- **Thing** — Trucks and trailers. Category enum: `truck | trailer`. Has many `WorkOrder`s.

- **WorkOrder** — Polymorphic: `workable` can be a `Location` or `Thing`. Has many `Comment`s.

- **User** — Devise authentication. Has `role` field; `User.workers` scope filters role='worker'.

### Notable Patterns

**Select2 AJAX endpoints** — Several controllers expose `search` and `select2`-style actions that return JSON for dynamic dropdown population (customers, locations, orders).

**Polymorphic associations** — `WorkOrder` uses `workable` polymorphic belonging to either `Location` or `Thing`.

**Nested attributes** — `Product` accepts nested `product_components` for BOM. `ProductionOrder` manages components and batches via nested forms.

**Status workflows** — `Dispatch` and `CustomerOrder` use Rails enums. `DispatchesController` has dedicated actions (`mark_as_complete`, `mark_as_billed`, `mark_as_sent_to_driver`) that transition status and optionally trigger Twilio SMS via `send_notification`.

**Frontend stack** — Bootstrap 5.3.2, Stimulus.js, Turbo.js (Hotwired), Select2, SortableJS, FullCalendar, jQuery, Trix (ActionText rich editor).

**File attachments** — Active Storage used on `Dispatch` for file uploads.

**Deployment** — Hosted on Render; build script at `bin/render-build.sh`.
