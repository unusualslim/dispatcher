-- FPS Team nightly invoice dates export (FPS_INVOICE_DATES_<date>.csv, with a header row).
-- The app finds columns by header name, so keep these aliases: Order_No, Invoice_No, Invoice_Date, Salesperson
-- (PdiInvoiceDateImportService). Window: orders invoiced in the last @Days days; re-sending is harmless.
SET NOCOUNT ON;

DECLARE @Days  int  = 30;
DECLARE @Since date = DATEADD(day, -@Days, CAST(GETDATE() AS date));

SELECT
    o.Ord_No            AS Order_No,
    o.Ord_Inv_No        AS Invoice_No,
    o.Ord_Inv_Date      AS Invoice_Date,
    sp.SalesPerson_Name AS Salesperson
FROM dbo.Orders AS o
LEFT JOIN dbo.SalesPersons AS sp
    ON sp.SalesPerson_Key = o.Ord_SalesPerson_Key
WHERE o.Ord_Inv_Date >= @Since
ORDER BY o.Ord_Inv_Date, o.Ord_No;
