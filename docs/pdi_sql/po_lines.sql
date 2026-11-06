-- FPS Team nightly PO lines export (FPS_PO_LINES_<date>.csv).
-- 56 columns in this exact order: the app reads them by position (PdiPurchaseOrderImportService).
-- Window: every PO still Entered/Ordered (so open POs keep refreshing) plus any PO with activity in the
-- last @Days days. Re-sending a PO is harmless: the app updates it in place.
SET NOCOUNT ON;

DECLARE @Days  int  = 14;
DECLARE @Since date = DATEADD(day, -@Days, CAST(GETDATE() AS date));

SELECT
    -- Header: references & status
    h.WhPrch_Key,
    h.WhPrch_PO_No                   AS PO_No,
    h.WhPrch_Invoice_No              AS Invoice_No,
    v.Vend_ID                        AS Vendor_ID,
    v.Vend_Description               AS Vendor_Name,
    t.APTerms_ID                     AS Terms_ID,
    t.APTerms_Description            AS Terms_Description,
    inv_s.Site_ID                    AS Invoice_Site_ID,
    inv_s.Site_Description           AS Invoice_Site_Name,
    CASE h.WhPrch_Status
        WHEN 0 THEN 'Entered'
        WHEN 1 THEN 'Ordered'
        WHEN 2 THEN 'Invoiced'
        WHEN 3 THEN 'Inventoried'
    END                              AS Status,
    CASE h.WhPrch_Doc_Type
        WHEN 0 THEN 'Standard'
        WHEN 1 THEN 'Purchase Order'
        WHEN 2 THEN 'Delivery Note'
        WHEN 3 THEN 'Invoice'
    END                              AS Doc_Type,
    CASE h.WhPrch_Source_Type
        WHEN 0 THEN 'Entered'
        WHEN 1 THEN 'Imported'
        WHEN 2 THEN 'Back Order'
        WHEN 3 THEN 'Third Party Warehouse Order'
    END                              AS Source_Type,

    -- Header: dates
    h.WhPrch_Order_Date              AS Order_Date,
    h.WhPrch_Sched_Delivery_Date     AS Delivery_Date,
    sm.WhShip_Description            AS Ship_Method,
    h.WhPrch_Business_Date           AS Business_Date,
    h.WhPrch_Invoice_Date            AS Invoice_Date,
    h.WhPrch_Post_Invent_DateTime    AS Posted_Inventory_DateTime,
    h.WhPrch_Post_Invc_DateTime      AS Posted_Invoice_DateTime,

    -- Header: amounts
    h.WhPrch_Invoice_Total           AS Invoice_Total,
    h.WhPrch_Other_Charges_Amt       AS Other_Charges,
    h.WhPrch_Discounts_Amt           AS Discounts,

    -- Header: freight
    CASE h.WhPrch_FrtInvc_Method
        WHEN 0 THEN 'No Separate Freight Charge'
        WHEN 1 THEN 'Freight On Same Invoice'
        WHEN 2 THEN 'Freight On Separate Invoice'
        WHEN 3 THEN 'Accrue Freight'
    END                              AS Freight_Method,
    h.WhPrch_Frt_On_Vend_Invc_Amt    AS Freight_On_Vendor_Invoice,
    h.WhPrch_Frt_Accrual_Amt         AS Freight_Accrual,
    fv.Vend_ID                       AS Freight_Vendor_ID,
    fv.Vend_Description              AS Freight_Vendor_Name,
    h.WhPrch_FrtInvc_No              AS Freight_Invoice_No,
    h.WhPrch_FrtInvc_Date            AS Freight_Invoice_Date,
    h.WhPrch_FrtInvc_Total           AS Freight_Invoice_Total,
    ft.APTerms_ID                    AS Freight_Terms_ID,
    ft.APTerms_Description           AS Freight_Terms_Description,
    h.WhPrch_Comments                AS Header_Comments,

    -- Line: warehouse & product
    d.WhPrchDtl_Key,
    ws.Site_ID                       AS Warehouse_ID,
    ws.Site_Description              AS Warehouse_Name,
    p.Prod_ID,
    p.Prod_Description,
    pp.ProdPkg_Pkg_Code              AS Purch_Pkg_Code,
    ip.ProdPkg_Pkg_Code              AS Invent_Pkg_Code,

    -- Line: quantities
    d.WhPrchDtl_Order_Qty            AS Order_Qty,
    d.WhPrchDtl_Purch_Qty            AS Purch_Qty,
    d.WhPrchDtl_Invoice_Qty          AS Invoice_Qty,
    d.WhPrchDtl_Invent_Qty           AS Invent_Qty,
    d.WhPrchDtl_BackOrd_Qty          AS BackOrder_Qty,
    d.WhPrchDtl_Invoice_Var_Qty      AS Invoice_Var_Qty,

    -- Line: costs
    d.WhPrchDtl_Unit_Cost            AS Unit_Cost,
    d.WhPrchDtl_Ext_Cost             AS Ext_Cost,
    d.WhPrchDtl_Ext_Discount         AS Ext_Discount,
    d.WhPrchDtl_Total_Cost           AS Line_Total_Cost,
    d.WhPrchDtl_Frt_In_Invent_Amt    AS Line_Freight,
    d.WhPrchDtl_OtherChg_In_Invent_Amt  AS Line_Other_Charges,
    d.WhPrchDtl_Discounts_In_Invent_Amt AS Line_Discounts,
    d.WhPrchDtl_Invoice_Var_Cost     AS Invoice_Var_Cost,

    -- Line: status
    CASE d.WhPrchDtl_Receiving_Status
        WHEN 0 THEN 'Not Started'
        WHEN 1 THEN 'In Progress'
        WHEN 2 THEN 'Completed'
    END                              AS Receiving_Status,
    d.WhPrchDtl_Comments             AS Line_Comments
FROM dbo.Warehouse_Purchases AS h
INNER JOIN dbo.Vendors AS v
    ON v.Vend_Key = h.WhPrch_Vend_Key
LEFT JOIN dbo.Vendors AS fv
    ON fv.Vend_Key = h.WhPrch_FrtInvc_Vend_Key
LEFT JOIN dbo.AP_Terms AS t
    ON t.APTerms_Key = h.WhPrch_APTerms_Key
LEFT JOIN dbo.AP_Terms AS ft
    ON ft.APTerms_Key = h.WhPrch_FrtInvc_Terms_Key
LEFT JOIN dbo.Warehouse_Shipping_Methods AS sm
    ON sm.WhShip_Key = h.WhPrch_Ship_Key
LEFT JOIN dbo.Sites AS inv_s
    ON inv_s.Site_Key = h.WhPrch_Invoice_Site_Key
INNER JOIN dbo.Warehouse_Purchase_Details AS d
    ON d.WhPrchDtl_WhPrch_Key = h.WhPrch_Key
INNER JOIN dbo.Sites AS ws
    ON ws.Site_Key = d.WhPrchDtl_Site_Key
INNER JOIN dbo.Products AS p
    ON p.Prod_Key = d.WhPrchDtl_Purch_Prod_Key
LEFT JOIN dbo.Product_Packages AS pp
    ON pp.ProdPkg_Key = d.WhPrchDtl_Purch_ProdPkg_Key
LEFT JOIN dbo.Product_Packages AS ip
    ON ip.ProdPkg_Key = d.WhPrchDtl_Invent_ProdPkg_Key
WHERE h.WhPrch_Status IN (0, 1)                        -- still open: Entered / Ordered
   OR h.WhPrch_Business_Date        >= @Since
   OR h.WhPrch_Order_Date           >= @Since
   OR h.WhPrch_Invoice_Date         >= @Since
   OR h.WhPrch_Post_Invent_DateTime >= @Since
   OR h.WhPrch_Post_Invc_DateTime   >= @Since
ORDER BY h.WhPrch_Key, d.WhPrchDtl_Key;
