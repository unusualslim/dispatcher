-- PDI repack batches (one row per batch x finished item x component), last 90 days by business date.
-- Exported nightly as FPS_REPACK_BATCHES_<yyyymmdd>.csv (with the header row) and imported by the app's
-- PDI Repack Batches Sync, the same import as Data Imports -> Repack Batches.
-- The app reads the columns by POSITION: keep this column order (Warehouse_ID is column 9, Warehouse_Name column 10).
-- Re-sending batches is harmless: batches already in the app are skipped, and an order that has no warehouse
-- gets it from Warehouse_ID (matched to the location's PDI site code).
SELECT
    -- Batch
    b.WhRpkgBat_Key                      AS Batch_Key,
    b.WhRpkgBat_Description              AS Batch_Description,
    b.WhRpkgBat_Business_Date            AS Business_Date,
    CASE b.WhRpkgBat_Posted
        WHEN 0 THEN 'Unposted'
        WHEN 1 THEN 'Posted'
        WHEN 2 THEN 'Reversed'
    END                                  AS Batch_Status,
    b.WhRpkgBat_Posted_Datetime          AS Posted_DateTime,
    b.WhRpkgBat_Entry_Datetime           AS Entry_DateTime,
    CASE b.WhRpkgBat_Source_Type
        WHEN 0 THEN 'Entry'
        WHEN 1 THEN 'Import'
        WHEN 2 THEN 'Autorepack'
    END                                  AS Batch_Source,
    CASE WHEN b.WhRpkgBat_Credit = 1
         THEN 'Yes' ELSE 'No' END        AS Credit_Batch,
    s.Site_ID                            AS Warehouse_ID,
    s.Site_Description                   AS Warehouse_Name,
    fs.Site_ID                           AS Fuel_Plant_ID,
    fs.Site_Description                  AS Fuel_Plant_Name,

    -- Repack (finished item)
    rp.WhRpkgProd_Key,
    rp_prod.Prod_ID                      AS Repack_Prod_ID,
    rp_prod.Prod_Description             AS Repack_Description,
    rp_pkg.ProdPkg_Pkg_Code              AS Repack_Pkg_Code,
    rp.WhRpkgProd_Qty                    AS Repack_Qty,
    CASE WHEN rp.WhRpkgProd_Overridden <> 0
         THEN 'Yes' ELSE 'No' END        AS Formula_Overridden,
    rp.WhRpkgProd_Comp_EstTotal_Ext_Cost AS Comp_Total_Cost,
    rp.WhRpkgProd_EstTotal_Ext_Fees      AS Total_Fees,
    rp.WhRpkgProd_Est_Total_Cost         AS Repack_Est_Total_Cost,
    CASE WHEN rp.WhRpkgProd_Fee <> 0 THEN
        CASE rp.WhRpkgProd_Fee_Method
            WHEN 0 THEN 'Per Unit'
            WHEN 1 THEN 'Per Batch'
        END
    END                                  AS Fee_Method,
    rp.WhRpkgProd_Fee_Actual_Amount      AS Fee_Actual_Amount,

    -- Byproduct (blank if none)
    bp_prod.Prod_ID                      AS ByProd_Prod_ID,
    bp_prod.Prod_Description             AS ByProd_Description,
    bp_pkg.ProdPkg_Pkg_Code              AS ByProd_Pkg_Code,
    rp.WhRpkgProd_ByProd_Actual_Qty      AS ByProd_Actual_Qty,
    rp.WhRpkgProd_ByProd_EstTotal_Ext_Cost AS ByProd_Total_Cost,

    -- Component (detail)
    c.WhRpkgComp_Key,
    c_prod.Prod_ID                       AS Comp_Prod_ID,
    c_prod.Prod_Description              AS Comp_Description,
    CASE c.WhRpkgComp_Prod_Type
        WHEN 0 THEN 'Fuel'
        WHEN 1 THEN 'Warehouse'
    END                                  AS Comp_Prod_Type,
    c_pkg.ProdPkg_Pkg_Code               AS Comp_Pkg_Code,
    c.WhRpkgComp_Tank_No                 AS Comp_Tank_No,
    c.WhRpkgComp_Default_Qty             AS Comp_Default_Qty_Per_Unit,
    c.WhRpkgComp_Actual_Qty              AS Comp_Actual_Qty_Per_Unit,
    c.WhRpkgComp_Actual_Qty * rp.WhRpkgProd_Qty AS Comp_Total_Qty_Used,
    c.WhRpkgComp_Estimated_Cost          AS Comp_Est_Unit_Cost,
    c.WhRpkgComp_Total_Ext_Cost          AS Comp_Total_Ext_Cost,
    CASE WHEN c.WhRpkgComp_Original <> 0
         THEN 'Original Formula'
         ELSE 'Added at Batch Entry'
    END                                  AS Comp_Source
FROM dbo.Warehouse_Repack_Batches AS b
INNER JOIN dbo.Warehouse_Repack_Products AS rp
    ON rp.WhRpkgProd_RpkgBat_Key = b.WhRpkgBat_Key
LEFT JOIN dbo.Sites AS s
    ON s.Site_Key = b.WhRpkgBat_Site_Key
LEFT JOIN dbo.Sites AS fs
    ON fs.Site_Key = b.WhRpkgBat_FuelComp_Site_Key
INNER JOIN dbo.Product_Packages AS rp_pkg
    ON rp_pkg.ProdPkg_Key = rp.WhRpkgProd_ProdPkg_Key
INNER JOIN dbo.Products AS rp_prod
    ON rp_prod.Prod_Key = rp_pkg.ProdPkg_Prod_Key
LEFT JOIN dbo.Product_Packages AS bp_pkg
    ON bp_pkg.ProdPkg_Key = rp.WhRpkgProd_ByProd_ProdPkg_Key
LEFT JOIN dbo.Products AS bp_prod
    ON bp_prod.Prod_Key = bp_pkg.ProdPkg_Prod_Key
LEFT JOIN dbo.Warehouse_Repack_Components AS c
    ON c.WhRpkgComp_RpkgProd_Key = rp.WhRpkgProd_Key
LEFT JOIN dbo.Products AS c_prod
    ON c_prod.Prod_Key = c.WhRpkgComp_Prod_Key
LEFT JOIN dbo.Product_Packages AS c_pkg
    ON c_pkg.ProdPkg_Key = c.WhRpkgComp_ProdPkg_Key
WHERE b.WhRpkgBat_Business_Date >= DATEADD(day, -90, CAST(GETDATE() AS date))
ORDER BY b.WhRpkgBat_Business_Date DESC, b.WhRpkgBat_Key, rp_prod.Prod_ID, c_prod.Prod_ID;
