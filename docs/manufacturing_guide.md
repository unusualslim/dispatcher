# LoadNTrucks — Manufacturing Guide

This guide covers production orders, batch management, QC, and how manufacturing connects to inventory.

---

## 1. Overview

The Manufacturing section manages DEF production and lube blending workflows:

1. A production order is created for a finished product with a quantity and due date
2. Components are auto-populated from the product's Bill of Materials
3. One or more production batches are run under the order
4. Each batch goes through a QC step before being marked complete
5. On completion, raw material components are deducted from inventory and finished goods are added

---

## 2. Production Orders

### Creating a Production Order

1. Go to **Manufacturing → Orders Table** and click **New Production Order**, or click **New** from the Kanban view
2. Fill in:
   - **Product** — the finished good being manufactured (must have a BOM set up)
   - **Qty to Make** — total quantity for this order
   - **Due Date** — when it needs to be finished
   - **Production Date** — when production is scheduled
   - **Customer / Location** — optional, links this run to a specific order or site
   - **Priority** — for your own sorting and planning
3. The **Components** section auto-populates from the product's BOM based on the qty to make
4. Add at least one batch (enter the quantity for that batch run)
5. Click **Save**

### Production Order Statuses

| Status | Meaning |
|---|---|
| Pending | Created, not yet started |
| In Progress | Production has begun |
| Completed | All batches complete, inventory updated |

### Recalculating Components

If you update the BOM after creating an order, or need to adjust quantities:

1. Open the production order and click **Edit**
2. Click **Recalculate from BOM**
3. The component list is rewritten based on the current BOM and qty to make
4. Save

---

## 3. Batches and Lot Numbers

A production order can have one batch (for a simple single run) or multiple batches (if production happens in separate runs). Each batch is tracked independently.

### Lot Number Format

Lot numbers are auto-generated: **FPS-XXXX-YYYYMMDD-NN**
- XXXX = sequence number
- YYYYMMDD = production date
- NN = batch number within the order

Lot numbers appear on batch labels and are used for traceability.

### Adding a Batch

While editing a production order, click **Add Batch** and enter the quantity for that run.

### Batch Fields

| Field | Purpose |
|---|---|
| Lot Number | Auto-generated traceability identifier |
| Quantity | How much this batch produces |
| QC Status | pending / passed / hold / rejected |
| Filled By | Who ran the batch |
| Approved By | Who signed off |

---

## 4. QC Workflow

Every batch must pass QC before inventory is updated.

### QC Statuses

| Status | Meaning |
|---|---|
| Pending | Awaiting QC review |
| Passed | QC approved — ready to complete |
| Hold | Flagged for review — not yet approved or rejected |
| Rejected | Failed QC — will not be completed |

### Running QC

1. Open the production order and scroll to the **Batches** section
2. In the **QC Status** dropdown for the batch, select the appropriate status
3. Click **Update QC**

A batch on **Hold** or **Rejected** cannot be completed. Update the status to **Passed** once any issues are resolved.

### Completing a Batch

Once QC status is **Passed**:

1. The **Complete Batch** button becomes available
2. Click **Complete Batch** to finalize

**What happens when you complete a batch:**
- The finished good quantity is added to inventory
- All BOM components are deducted from inventory (using actual quantities if recorded, otherwise proportional to batch quantity)
- An inventory transaction is created for each stock movement
- The system checks whether any raw material has dropped below its reorder point
- If a reorder point is breached, a draft Purchase Order is created automatically and admin users are notified by email

---

## 5. Kanban vs. Table View

### Prod. Orders (Kanban)

The kanban view shows production orders on a calendar-style grid organized by production date, color-coded by status:
- **Gray** — Pending
- **Blue** — In Progress
- **Green** — Completed

Use the kanban for scheduling and getting a visual picture of the production workload by day.

### Orders Table

The table view shows all production orders in a searchable, filterable list. Use this to:
- Find a specific order by product, date, or status
- Review completed orders
- Export production history

---

## 6. How Manufacturing Connects to Inventory

| Event | Inventory Impact |
|---|---|
| Batch completed | Components deducted (out transactions); finished good added (in transaction) |
| Batch rejected | No inventory impact |
| Reorder point breached after completion | Draft PO created automatically |

All inventory movements from production are logged in **Inventory History** and are linked to the batch lot number for traceability.

---

## 7. Batch Labels

Batch labels can be printed directly from the production order. Labels include:
- Product name and lot number
- QR code for scanning
- Production date and quantity

To print labels, open the production order and use the **Print Labels** option.

---

## 8. FAQ

**Q: The Components section is empty on a new production order.**
The product does not have a BOM set up yet. Go to **Inventory & MRP → Products**, open the product, click Edit, and add components in the Bill of Materials section. Then come back to the production order and click Recalculate from BOM.

**Q: I completed a batch but inventory didn't change.**
Check the product — if it has no BOM components, no deductions will occur. Also check that the finished product is not flagged as a raw material, which would skip the finished goods credit.

**Q: A batch failed QC after I already marked it passed. Can I change it back?**
Yes. Open the production order, find the batch, change the QC status to Hold or Rejected, and click Update QC. As long as you have not clicked Complete Batch, no inventory has been affected.

**Q: Can I split a large production run into multiple batches?**
Yes. Add multiple batches to a single production order, each with its own quantity. Each batch gets its own lot number and goes through QC independently. This is the recommended approach for large runs that happen over multiple days or shifts.

**Q: How do I see what components were used in a completed batch?**
Go to **Inventory & MRP → Inventory History** and filter by the component product. Each deduction transaction shows the lot number it was linked to.

**Q: What happens if we don't have enough raw material to complete a batch?**
The system does not currently block completion if stock would go negative — it will complete the batch and the stock count will go negative. Use the MRP Dashboard beforehand to check material availability, and run a reorder if needed.
