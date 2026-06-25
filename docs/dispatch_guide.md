# LoadNTrucks — Dispatch & Orders Guide

This guide covers customer orders, dispatch assignments, drivers, and the calendar and map views.

---

## 1. Overview

The Dispatch section manages the full order-to-delivery workflow:

1. A customer order is created for a delivery location
2. A dispatch is created to assign a driver and truck to fulfill one or more orders
3. The driver is notified and the dispatch appears on the map
4. The dispatch is marked complete once the delivery is done

---

## 2. Customer Orders

### Creating an Order

1. Click **Orders** in the sidebar
2. Click **New Order**
3. Fill in:
   - **Customer** — select from the customer list
   - **Location** — the delivery site (destination)
   - **Products** — add one or more products with quantities
   - **Order Date** and **Requested Delivery Date**
   - **Notes** — any special instructions
4. Click **Save** — the order is created with status **New**

### Order Statuses

| Status | Meaning |
|---|---|
| New | Open, not yet dispatched |
| Complete | Delivered and closed |
| On Hold | Paused — not available for dispatch |
| Deleted | Cancelled — hidden from active views |

### Adding Products to an Order

On an existing order, use the **Add Product** section at the bottom to add line items. Each line has a product, quantity, and optional notes. Products can be added or removed at any time before the order is dispatched.

---

## 3. Dispatches

A dispatch links a driver and truck to one or more customer orders for a specific delivery run.

### Creating a Dispatch

1. Open a customer order and click **Create Dispatch**, or go to **Dispatches → New**
2. Fill in:
   - **Driver** — the user assigned to this run
   - **Truck** — the asset being used
   - **Origin Terminal** — where the load departs from (a Location with category Origin)
   - **Dispatch Date** — the scheduled date
   - **Customer Orders** — add one or more orders to this dispatch
3. Click **Save**

### Dispatch Statuses

| Status | Meaning |
|---|---|
| Pending | Created, not yet sent to driver |
| Sent to Driver | Driver has been notified; shows on map |
| Complete | Delivery finished |
| Billed | Invoice has been sent |

### Notifying the Driver

Open a dispatch and click **Send to Driver**. This sends the driver a notification and changes the status to "Sent to Driver." The dispatch also appears as a route line on the Map view.

### Completing a Dispatch

Open the dispatch and click **Mark as Complete**. This closes out the delivery. Individual customer orders can then be marked complete separately if needed.

---

## 4. Dispatches Table

Click **Dispatches** in the sidebar to see the full dispatches table. This view shows all dispatches with filters for date range, driver, and status. Use this for reviewing history or finding a specific run.

---

## 5. Dispatch Kanban

Click **Dispatch Kanban** in the sidebar to see dispatches organized by status in a kanban board. Good for a quick overview of what is in progress versus complete.

---

## 6. Calendar

Click **Calendar** in the sidebar to see dispatches and customer orders laid out by date. Events are color-coded by type. Click any event to open the dispatch or order detail.

Use the calendar to:
- Spot scheduling conflicts (two dispatches on the same driver on the same day)
- Plan workload by week
- See upcoming deliveries at a glance

---

## 7. Map

Click **Map** in the sidebar to see a live map of:

- **Origin terminals** — blue markers
- **Customer delivery sites** — red markers
- **Active dispatch routes** — colored lines from origin to destination
- **Live truck locations** — GPS positions from Samsara (updated automatically)

Route line colors indicate urgency by days until dispatch date:
- **Green** — more than 3 days out
- **Yellow** — 2–3 days out
- **Orange** — tomorrow
- **Red** — today or overdue

---

## 8. Master Data

### Customers

Click **Customers** in the sidebar to manage the customer list. Each customer record holds name, contact info, and address. Customers are linked to their delivery locations.

### Locations

Click **Locations** in the sidebar to manage terminals and delivery sites.

- **Origin terminals** (category: Origin) — where loads depart from. These appear as the starting point for dispatch routes on the map.
- **Destination sites** (category: Destination) — customer delivery addresses. These are the delivery endpoints.

Each location has a name, address, GPS coordinates (used for map placement and route calculation), and can have products associated with it.

### Drivers & Users

Click **Drivers** in the sidebar to manage user accounts. Drivers have the **driver** role — they can only see their own assigned dispatches. Admins and workers have access to the full application.

### Assets (Trucks)

Click **Assets** in the sidebar to manage vehicles and equipment. Each asset has a name, type, and can be assigned to dispatches. Asset maintenance history is tracked through Work Orders.

### Vendors

Click **Vendors** in the sidebar to manage supplier records. Vendors are linked to purchase orders in the Inventory & MRP section.

---

## 9. Messages & Announcements

### Messages

Click **Messages** to see dispatch-related messages sent between staff and drivers. Messages are tied to specific dispatches.

### Announcements

Click **Announcements** to post company-wide notices visible to all users when they log in.

---

## 10. FAQ

**Q: A driver can't see their dispatch. What do I check?**
Make sure the dispatch status is **Sent to Driver** — dispatches in Pending status are not visible to drivers. Also confirm the driver is assigned to the correct user account.

**Q: How do I cancel an order?**
Open the order and set the status to **Deleted**. This hides it from active views but keeps the record for history.

**Q: Can one dispatch cover multiple customer orders?**
Yes. When creating or editing a dispatch, you can add multiple customer orders to it. This is the normal workflow for a single driver making multiple stops on one run.

**Q: The map isn't showing a truck I know is out.**
Live truck data comes from Samsara GPS. If a truck isn't showing, it may not have an active GPS signal, or the vehicle may not be configured in Samsara. The map refreshes automatically — no need to reload the page.

**Q: How do I export dispatch history?**
From the Dispatches table, use the **Export CSV** button to download the current filtered view.
