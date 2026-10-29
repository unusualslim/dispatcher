# Freight

Freight has two sides:

- **Purchase**: what a carrier charges us.
- **Sale**: what we charge the customer.

The app works out both, shows the freight margin, and creates a **payable** for what we owe the carrier.

---

## Setting up (Sales → Freight Rules)

### Classes
A freight class says how much of a bulk product fits on a full truckload (Class A = 8,500 gal, and so on).
Per-load freight divides an order's quantity by the class to count loads. For example, 9,000 gal of a Class A product is 2 loads.

- Add classes on the **Classes** tab.
- Put products in a class there. You can do a whole PDI category at once, or a list of product IDs. You can also set a product's class on its edit page.
- Only products with a class get calculated freight. Warehouse goods use manual charges (see below).

### Tables
A table is a freight index: you look up a rate in it. Each table has a lookup type:

| Lookup | You enter | Example |
|---|---|---|
| **Mileage** | Miles from / to, rate | 0–50 mi = 0.045, 50–100 mi = 0.06, over 100 mi = 0.08 |
| **Point to point** | Origin, destination, rate | Bainbridge terminal → Cordele Shop = 0.052 |
| **Flat** | One rate | Fuel surcharge 12 (%), pump off 50 ($) |

Rates can be pasted straight from Excel with **Paste rates** on the table page. Pasting replaces all of the table's rates.

### Rules
A rule says **when** to use a table and **what its rate means**.

- **Side**: Purchase (carrier cost) or Sale (charge the customer).
- **Charge**:
  - Freight
  - Fuel surcharge
  - Additional stop
  - Pump off
- **Basis**, which is what the rate means:
  - Per gallon / unit
  - Per load
  - Per additional stop
  - Per pump off
  - Percent of freight (fuel surcharge)
  - Flat per order
  - **Purchase cost + markup**, for sale rules that mark up a third-party carrier's cost
- **When it applies**: origin, freight class, carrier, customer, and the effective dates. A blank field matches any order.
- **Minimum $** (optional): the charge never goes below it.

When more than one rule matches, the most specific one wins. A rule naming the customer beats one naming the carrier. Carrier beats origin, and origin beats class. Ties go to the newest effective date.

---

## Freight on a customer order

The **Freight** card on an order has these fields:

- **Origin**: defaults to the ship-from warehouse, the PDI warehouse on the lines, or the dispatch's terminal.
- **Carrier**: defaults to PDI's carrier on the order.
- **Miles**: blank uses a GPS estimate (straight line × 1.2). Type the real miles to override it.
- **Extra stops** and **Pump offs**.
- **Customer sees freight**: on a **separate line item**, or **rolled into the price**. Rolled in, each product line shows its delivered price per unit.

Click **Calculate freight** (or **Save**) to apply the rules. The card shows:

- the sale charges and the carrier cost
- the **freight margin**
- for PDI orders that already have freight lines, PDI's billed freight next to the calculated amount, for comparison

### Warehouse goods and carrier quotes
Use **Add a freight charge by hand**:

- Enter the carrier cost (with the carrier), then the customer charge.
- For the customer charge, type an amount, or a markup % to charge the carrier cost plus that markup.
- Manual charges stay when freight is recalculated. Calculated charges are replaced each time.

Carrier cost on an order creates a payable for that carrier. Five Points Logistics and Five Points Service payables are marked **intercompany**.

---

## Freight on a purchase order

The **Freight** card on a PO has these fields:

- **Freight amount**.
- **Spread over lines**: **by quantity** or **by value**. The table shows each line's freight and **landed unit cost**, which is what posts to inventory.
- **Billed by**:
  - **The vendor's invoice**: freight is a line on the vendor's bill, so no separate payable.
  - **Separate carrier**: pick the carrier and enter their invoice #, invoice date and amount. This creates a carrier payable.
- **BOL #**.
- **Amount is an estimate (accrue)**: tick this when you don't know the real freight at receipt.

When the carrier's invoice arrives:

- **Before** the PO is posted to inventory, the invoice amount replaces the estimate.
- **After** posting, the estimate stays in inventory and the difference shows as a **variance** on the payable.

---

## Freight Payables (Purchasing → Freight Payables)

Every carrier payable, from POs and from customer orders:

- **Accrued** until the invoice # and amount are entered, then **Invoiced**.
- Filter by carrier. The **Variance** column shows how far the invoice was from the accrual.

---

## Not built yet

- Exporting freight payables to PDI AP, and GL postings for freight revenue, cost and accruals.
- Carrier lanes (quoted rates per lane) pulled into tables.
- Road-routed miles. Miles are a GPS estimate unless typed in.
