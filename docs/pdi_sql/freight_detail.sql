-- FPS Team nightly freight detail export (FPS_FREIGHT_DETAIL_<date>.csv, with a header row).
-- PDI's freight in detail: the rules behind each line's freight (base rate, FPLFSC / TAFSC / MANFSC / PBLFSC…),
-- which the order API only sends as one per-gallon freight figure. The app finds columns by header name, so keep
-- the aliases. Two parts:
--   LOAD  = load components (Order_Fuel_Load_Freight), the purchase side, loads with a business date in the window
--   ORDER = fuel detail components (Order_Details_Fuel_Freight), the sale side, orders with a business date in it
-- Window: the last @Days days (same as the app's nightly fuel load sync); re-sending rows is harmless.
-- Components not tied to a load line (no LoadFrt_LoadDtl_Key) are left out: per-load charges come from the API.
SET NOCOUNT ON;

DECLARE @Days  int  = 120;
DECLARE @Since date = DATEADD(day, -@Days, CAST(GETDATE() AS date));

SELECT
    'LOAD'                     AS Source,
    lf.LoadFrt_Key             AS Component_Key,
    ld.Load_Key                AS Load_No,
    ld.Load_Reference_No       AS Load_Reference_No,
    ld.Load_Business_Date      AS Business_Date,
    o.Ord_No                   AS Order_No,
    ld.LoadDtl_Bill_Of_Lading  AS BOL,
    ld.Prod_ID                 AS Product_ID,
    ld.LoadDtl_Key             AS Line_Key,
    ld.LoadDtl_Frt_Total_Cost  AS Line_Freight,
    r.FuelFrtRule_Description  AS Rule_Name,
    lf.LoadFrt_Type            AS Rule_Type,
    lf.LoadFrt_Purchase        AS Purchase,
    lf.LoadFrt_Sale            AS Sale,
    lf.LoadFrt_Method          AS Method,
    lf.LoadFrt_Basis           AS Basis,
    lf.LoadFrt_Rate            AS Rate,
    lf.LoadFrt_Amt             AS Amount
FROM dbo.Order_Fuel_Load_Freight AS lf
JOIN dbo.Order_Fuel_Load_Dtls_All AS ld
    ON ld.LoadDtl_Key = lf.LoadFrt_LoadDtl_Key
LEFT JOIN dbo.Order_Details_Fuel AS f
    ON f.OrdFuel_Key = ld.LoadDtl_OrdFuel_Key
LEFT JOIN dbo.Orders AS o
    ON o.Ord_Key = f.OrdFuel_Ord_Key
LEFT JOIN dbo.Fuel_Freight_Rules AS r
    ON r.FuelFrtRule_Key = lf.LoadFrt_FrtRule_Key
WHERE ld.Load_Business_Date >= @Since

UNION ALL

SELECT
    'ORDER',
    ff.OrdFuelFrt_Key,
    NULL,
    NULL,
    ff.Ord_Business_Date,
    ff.Ord_No,
    NULL,
    p.Prod_ID,
    ff.OrdFuel_Key,
    ff.OrdFuel_Frt_Total_Price,
    ff.FuelFrtRule_Description,
    ff.OrdFuelFrt_Type,
    ff.OrdFuelFrt_Purchase,
    ff.OrdFuelFrt_Sale,
    ff.OrdFuelFrt_Method,
    ff.OrdFuelFrt_Basis,
    ff.OrdFuelFrt_Rate,
    ff.OrdFuelFrt_Amt
FROM dbo.Order_Details_FuelFrt_All AS ff
LEFT JOIN dbo.Order_Details_Fuel AS f
    ON f.OrdFuel_Key = ff.OrdFuel_Key
LEFT JOIN dbo.Products AS p
    ON p.Prod_Key = COALESCE(f.OrdFuel_Prch_Prod_Key, f.OrdFuel_Ord_Prod_Key)
WHERE ff.Ord_Business_Date >= @Since

ORDER BY Source, Business_Date, Line_Key, Component_Key;
