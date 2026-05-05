# LoadNTrucks — Inventory & MRP User Guide

This guide covers the inventory tracking, production, and purchasing features added to LoadNTrucks. It is written for dispatch staff, production staff, and purchasing staff who are familiar with the business but new to these tools.

---

## 1. Overview

The **Inventory & MRP** section of LoadNTrucks tracks:

- How much of each raw material (components, additives, totes, etc.) you have on hand
- Which raw materials go into each finished product and in what amounts (the Bill of Materials)
- Production batches — what was made, when, in what quantity, and what materials were used
- Purchase orders to replenish stock
- A 30-day planning view that shows what you will need and whether you have enough to fill upcoming orders

The goal is to avoid production stoppages because a component ran out, and to avoid over-ordering by knowing exactly what is on hand and what is already on the way.

---

## 2. Key Concepts

**Product**
Any item tracked in inventory — either a raw material/component (DEF additive, tote, label, etc.) or a finished good (packaged DEF, blended lubricant, etc.). Each product has a name, part number, unit of measure, and stock quantity.

**Raw Material vs. Finished Good**
Products are flagged as either a raw material or a finished good. Raw materials are what you buy and consume in production. Finished goods are what you manufacture and ship to customers.

**Bill of Materials (BOM)**
A recipe. For a finished product, the BOM lists every raw material component and how much of it is needed to make one unit. For example: to make one tote of DEF, you might need X gallons of urea solution and Y labels. The BOM is stored on the product and is used to auto-populate production orders.

**Reorder Point / Safety Stock**
The reorder point is the quantity at which you should place a new order — the system will flag anything at or below this level. Safety stock is the minimum buffer you want to keep on hand at all times and is not counted as "available" for production planning purposes.

**Production Order**
A formal work order to make a quantity of a finished product. Each production order references the product being made, the quantity, the due date, and contains a component list (from the BOM). A production order can have one or more batches.

**Batch / Lot**
A single production run within a production order. Each batch gets a unique lot number (format: FPS-XXXX-YYYYMMDD-NN) for traceability. Batches go through a QC step before being marked complete.

**Purchase Order (PO)**
A request to a vendor to supply a raw material. POs move through a status workflow: Draft → Pending Approval → Approved → Submitted → Received.

**MRP (Material Requirements Planning)**
The 30-day planning view. It looks at all open customer orders due in the next 30 days, calculates the raw materials needed based on the BOMs, and compares that to current stock. It shows you shortfalls and suggests what to order.

---

## 3. Navigation

All features in this guide are under **Inventory & MRP** in the left sidebar:

| Menu Item | What It Does |
|---|---|
| MRP Dashboard | 30-day planning view — shortfalls, stock levels, open POs |
| Products | Product master — raw materials and finished goods |
| Purchase Orders | Buy raw materials from vendors |
| Adjust Inventory | Manual stock correction |
| Inventory History | Full audit log of every stock movement |
| Import from PDI | Bulk update stock levels from a PDI warehouse export |

Production orders are under **Manufacturing** in the sidebar:

| Menu Item | What It Does |
|---|---|
| Prod. Orders | Kanban view of production orders by date |
| Orders Table | Searchable table view of all production orders |

---

## 4. Products

### Finding a Product

Click **Products** in the sidebar. The list shows all products with their current stock, reorder point, and a status badge (OK / Low / Critical).

### Adding a New Product

1. Click **New Product**
2. Fill in: Name, Part Number, Unit of Measurement, and whether it is a raw material (check **Is Raw Material** for components; leave unchecked for finished goods)
3. Optionally set: Cost Per Unit, Reorder Point, Safety Stock, Current Stock
4. For finished goods, add components in the **Bill of Materials** section (see below)
5. Click **Save**

### Setting Up a Bill of Materials

On a finished good's product page, the BOM section lists the components and how much of each is needed per unit produced.

1. Open the product and click **Edit**
2. In the **Bill of Materials** section, click **Add Component**
3. Search for and select the raw material product, enter the quantity per unit and the unit of measure
4. Repeat for each component
5. Save

Getting the BOM right is important — production orders and MRP planning both depend on it.

---

## 5. Production Orders

### Creating a Production Order

1. Go to **Manufacturing → Prod. Orders** or **Orders Table**
2. Click **New Production Order**
3. Fill in:
   - **Product** — what you are making (select from finished goods)
   - **Qty to Make** — the total quantity for this order
   - **Due Date** — when it needs to be done
   - **Production Date** — when production is scheduled
   - **Customer / Location** — optional, links this order to a specific customer or site
   - **Priority** — for your own sorting
4. The **Components** section will auto-populate from the BOM. If the BOM has changed since the order was created, click **Recalculate from BOM** to refresh the list.
5. Add at least one batch in the **Batches** section (enter the quantity for that batch run)
6. Click **Save**

### Recalculating Components

If you update the BOM after creating a production order, open the order, click **Edit**, and click **Recalculate from BOM**. This rewrites the component list based on the current BOM and the qty to make.

### Managing Batches

A production order can have one batch (for simple runs) or several (if you produce in multiple runs). Each batch tracks its own lot number and QC status.

To add a batch while editing an order, click **Add Batch** and enter the quantity.

### Completing a Batch (QC and Inventory Deduction)

When a batch is finished:

1. Open the production order and scroll to the **Batches** section
2. In the **QC Status** dropdown for the batch, select **Passed** (or Hold / Rejected if there is an issue)
3. Click **Update QC**
4. Once QC is passed, the **Complete Batch** button becomes available
5. Click **Complete Batch** to finalize

When you complete a batch:
- The finished good quantity is added to inventory
- All BOM components are deducted from inventory (using actual quantities if recorded, otherwise proportional to the batch quantity)
- An inventory transaction record is created for each movement
- The system automatically checks whether any raw materials have dropped below their reorder point and creates draft purchase orders if needed

### Kanban vs. Table View

**Prod. Orders** (kanban) shows a calendar-style grid organized by production date, color-coded by status. Good for scheduling and seeing what is happening when.

**Orders Table** shows all orders in a searchable/filterable list. Good for finding a specific order or reviewing history.

---

## 6. Inventory

### Adjusting Stock Manually

Use **Adjust Inventory** when you need to correct the stock count — for example, after a physical count, a spill, a QC sample draw, or a manual receipt of goods.

1. Click **Adjust Inventory** in the sidebar
2. Select the **Product**
3. Choose **Direction**: In (adding stock) or Out (removing stock)
4. Enter the **Quantity**
5. Select a **Reason**: Count Correction, Spill/Loss, Sample/QC Draw, Manual Receipt, Damaged Goods, Transfer In, Transfer Out, or Other
6. Add any **Notes** for the record
7. Click **Save**

Every adjustment is logged in Inventory History with the reason, the user who made it, and the timestamp.

### Viewing Inventory History

Click **Inventory History** in the sidebar to see every stock movement — production completions, PO receipts, manual adjustments, and imports. You can filter by product to see just that product's history.

### Importing Stock from PDI

Use **Import from PDI** to bulk-update stock levels from the PDI warehouse inventory report. This is designed to be run daily.

1. Export the "Warehouse Inventory Report" from PDI as an .xlsx file
2. Click **Import from PDI** in the sidebar
3. Select the product type:
   - **Components (raw materials)** — for the component inventory report
   - **Finished Products** — for finished goods inventory
4. Choose your .xlsx file and click **Preview Import**
5. The preview screen shows every row from the file with:
   - The part number and description
   - The quantity from PDI
   - Whether the system will **Update** an existing product (matched by part number) or **Create** a new product
   - The current stock vs. the new value for updates
6. Use **Select All**, **Updates Only**, or **Deselect All** to choose which rows to apply. Uncheck any rows you want to skip.
7. Click **Confirm Import**

The system matches products by part number. If a product in the PDI file has no matching part number in LoadNTrucks, it will be listed as a new product to create. New components are created as raw materials; new finished products are created as finished goods.

---

## 7. Purchase Orders

### Viewing Purchase Orders

Click **Purchase Orders** in the sidebar. Orders are grouped by status: Draft, Pending Approval, Approved, Submitted, Received, and Cancelled.

### Creating a Purchase Order Manually

1. Click **New Purchase Order**
2. Select the **Product** (raw material) and **Vendor**
3. Enter **Quantity**, **Unit Cost**, and **Expected Delivery Date**
4. Set the **Trigger Type** to "Manual" if you are creating it by hand
5. Add any notes
6. Click **Save** — the PO is created as a Draft

### Approving a PO

Open a Draft or Pending Approval PO and click **Approve**. The system records who approved it and sets the expected delivery date based on the vendor's lead time.

### Marking a PO as Received

When stock arrives:

1. Open the PO and click **Mark as Received**
2. The system adds the ordered quantity to the product's current stock and creates an inventory transaction record

### Automatic Draft POs

The system creates Draft POs automatically in two situations:

1. **After a batch is completed** — if completing the batch causes any raw material to drop below its reorder point, a draft PO is created for that material
2. **MRP shortfall** — from the MRP Dashboard, you can create a PO for any identified shortage

Auto-generated POs are always created as Drafts. Someone still needs to review and approve them before submitting to the vendor.

When draft POs are created automatically, admin/manager users who have email notifications enabled will receive an email summary.

---

## 8. MRP Dashboard

Click **MRP Dashboard** in the sidebar.

The dashboard has three sections:

### Material Requirements (Next 30 Days)

This table looks at every open customer order with a delivery date in the next 30 days, explodes the BOM for each ordered product, and totals up how much of each raw material is needed. It then compares that to your current available stock (current stock minus safety stock).

| Column | Meaning |
|---|---|
| Material | The raw material name |
| Total Needed | How much is required to fill all orders in the next 30 days |
| Available | Current stock minus safety stock |
| Shortfall | How much you are short (0 means you have enough) |
| Vendor | The preferred vendor for this material |
| Lead Time | How many days it takes to receive after ordering |
| Order By | The latest date you can place the order and still receive in time |
| Urgent | Highlighted in red if there is a shortfall |

Click **Create PO** next to any shortfall row to create a draft purchase order for that material.

### Raw Material Stock Levels

A table of all raw materials showing current stock, safety stock, reorder point, available stock, and status badge. Status badges:
- **OK** — stock is above reorder point
- **Low** — stock is between safety stock and reorder point
- **Critical** — stock is at or below safety stock

### Open Purchase Orders

Counts of Draft and Pending Approval POs with a link to the Purchase Orders page.

---

## 9. What the System Does Automatically

| Trigger | What Happens Automatically |
|---|---|
| Batch marked Complete | Components are deducted from inventory; finished goods are added; inventory transactions are created; reorder check runs; draft POs created if any material drops below reorder point |
| PO marked Received | Product stock increases by PO quantity; inventory transaction created |
| MRP Dashboard opened | 30-day demand is recalculated live from open customer orders |
| PDI Import confirmed | Stock levels updated in bulk; new products created if part number not found |

---

## 10. What Requires Manual Action

- Reviewing and approving auto-generated Draft POs before submitting to vendors
- Marking POs as Submitted and Received after the physical transaction occurs
- Running the PDI import (this is a manual upload, not an automatic sync)
- Entering actual component quantities on batch records (the system defaults to proportional from the BOM)
- Updating the BOM when a formula changes
- Adjusting stock after a physical count

---

## 11. DEF and Lubricant Notes

The production order and BOM system is general-purpose, but it is designed for DEF production and lube blending workflows:

- **Lot numbers** are auto-generated in FPS format (FPS-XXXX-YYYYMMDD-NN) suitable for traceability and label printing
- **QC hold and reject statuses** on batches allow a batch to be flagged for review before it is released to inventory
- **BOM quantities** support up to three decimal places, which is needed for additive amounts in blending
- **Unit of measure** is set per BOM line, so gallons, liters, and each (labels, totes) can all coexist in the same formula
- The **Sign-Off** fields on a production order (Filled By, Approved By, Production Date) are designed for batch record documentation

---

## 12. FAQ

**Q: A raw material was delivered but I haven't created a PO for it. How do I add it to inventory?**
Use **Adjust Inventory** with direction "In" and reason "Manual Receipt." This updates the stock and logs the transaction.

**Q: The MRP Dashboard shows a shortfall but I know we have stock. Why?**
The available stock calculation subtracts safety stock from current stock. If the safety stock is set high relative to what is on hand, available stock will be lower than the physical count. Check the product's safety stock setting, or adjust the physical stock via Inventory Adjustment if there was a data entry error.

**Q: A batch failed QC. What do I do?**
Set the QC Status to **Rejected** or **Hold** and click Update QC. Do not click Complete Batch — this prevents inventory from being updated for that batch. You can update the status again once the issue is resolved.

**Q: The BOM was wrong when I created a production order. Can I fix it?**
Yes. Go to the product and correct the BOM first. Then open the production order, click Edit, and click **Recalculate from BOM**. The component list on the order will be updated.

**Q: I imported from PDI and a product showed up as "New Product" but it already exists in the system. Why?**
The import matches by part number. If the existing product in LoadNTrucks does not have a part number set (or has a different part number than the PDI export), it will not match. Open the product in LoadNTrucks, add the correct part number, and re-run the import.

**Q: Who receives the email when draft POs are auto-created?**
Users whose accounts have email notifications enabled (set in their profile). If you are not receiving these emails, check your profile settings.

**Q: How do I see what raw materials went into a specific batch?**
Open the production order and find the batch. The component list on the production order shows what was planned. The **Inventory History** page, filtered to the relevant component, will show the deduction transaction linked to that batch.

**Q: Can I create a purchase order before there is a shortfall?**
Yes. Use **Purchase Orders → New Purchase Order** and set the trigger type to "Manual." You do not need to wait for the MRP to flag a shortage.
