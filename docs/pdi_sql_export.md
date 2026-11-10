# Nightly PDI SQL export (PO lines + invoice dates)

A scheduled job on the PDI SQL Server writes two CSVs every night into an export folder. Your existing WinSCP
setup uploads them to the PDI FTP folder `/Imports`, and FPS Team picks them up with two automated processes:

| File | App process | Layout |
|---|---|---|
| `FPS_PO_LINES_<yyyymmdd>.csv` | PDI PO Lines Sync | 56 columns, **no header**: exactly the file Data Imports → PDI Purchase Orders takes today |
| `FPS_INVOICE_DATES_<yyyymmdd>.csv` | PDI Invoice Dates Sync | Header row; columns found by name: order number, invoice date, optional invoice # and salesperson (Data Imports → PDI Invoice Dates) |
| `FPS_FREIGHT_DETAIL_<yyyymmdd>.csv` | PDI Freight Detail Sync | Header row; PDI's freight in detail (base rate, FPLFSC, TAFSC, MANFSC…) per load line and order line, from `docs/pdi_sql/freight_detail.sql`. Keep its column aliases |

The app imports every waiting file oldest first, keeps each one on its log (Automated Processes → the process →
download), and deletes it from FTP once it imported. A file that fails stays on FTP and is retried the next night.
Other FTP jobs never touch `FPS_*.csv` names, and these jobs touch nothing else.

## 1. Folders and queries

On the SQL Server (or any Windows machine that can reach it):

```
C:\fps\pdi-export\
  sql\po_lines.sql        your PO lines query (the one you export today)
  sql\invoice_dates.sql   your invoice dates query
  sql\freight_detail.sql  freight in detail (docs/pdi_sql/freight_detail.sql)
  out\                    the CSVs (default $OutDir; WinSCP uploads from here)
  logs\
  export.ps1              the script below
```

The CSVs go to an output folder (`$OutDir` in the script): a local folder or a share (`\\server\share\fps`)
that the WinSCP server reads.

Change both queries to send a **rolling window** instead of all history. Re-sending rows is harmless (both
imports update in place), so overlap generously:

- PO lines: POs entered, changed or received in the last 14 days.
- Invoice dates: orders invoiced in the last 30 days.
- Freight detail: loads and orders with a business date in the last 120 days (matches the app's fuel load sync).

The PO lines query is in `docs/pdi_sql/po_lines.sql` (56 columns, open POs + 14 days of activity).
Keep its 56 columns in this order: the app reads them by position.
The invoice dates query is in `docs/pdi_sql/invoice_dates.sql`; keep its column aliases (Order_No, Invoice_No,
Invoice_Date, Salesperson): the app finds those columns by header name. Dates can stay as SQL dates: the script writes them
as `2026-11-05 00:00:00` (US-style `11/5/2026` would be misread by the PO import).

## 2. The script (`export.ps1`)

Needs the `SqlServer` PowerShell module (once, in PowerShell as admin: `Install-Module SqlServer -AllowClobber -Scope AllUsers`;
`-AllowClobber` is needed because SQL Server's older SQLPS module also has an `Invoke-Sqlcmd`). Fill in the three
settings at the top.

```powershell
$ErrorActionPreference = 'Stop'
Import-Module SqlServer -DisableNameChecking   # the new module, not SQL Server's older SQLPS
$Server   = 'PDISQL'                 # SQL Server instance
$Database = 'PDI'                    # PDI database name
$OutDir   = 'C:\fps\pdi-export\out'   # where WinSCP picks the files up (local folder or \\server\share)
$Root     = 'C:\fps\pdi-export'

$stamp = Get-Date -Format yyyyMMdd
Start-Transcript -Path "$Root\logs\export_$stamp.log" -Append

# Runs a query and writes it as UTF-8 CSV: dates as yyyy-MM-dd HH:mm:ss, NULLs empty. No file for no rows.
function Export-Query($SqlFile, $OutFile, [switch]$NoHeader) {
  $table = Invoke-Sqlcmd -ServerInstance $Server -Database $Database -InputFile $SqlFile `
                         -OutputAs DataTables -QueryTimeout 900 -TrustServerCertificate
  if (-not $table -or $table.Rows.Count -eq 0) { Write-Output "No rows from $SqlFile"; return }
  $rows = foreach ($row in $table.Rows) {
    $o = [ordered]@{}
    foreach ($col in $table.Columns) {
      $v = $row[$col.ColumnName]
      if ($v -is [DBNull]) { $v = '' }
      elseif ($v -is [datetime]) { $v = $v.ToString('yyyy-MM-dd HH:mm:ss') }
      $o[$col.ColumnName] = $v
    }
    [pscustomobject]$o
  }
  $csv = $rows | ConvertTo-Csv -NoTypeInformation
  if ($NoHeader) { $csv = $csv | Select-Object -Skip 1 }
  [IO.File]::WriteAllLines($OutFile, $csv, [Text.UTF8Encoding]::new($false))
  Write-Output "$($table.Rows.Count) rows -> $OutFile"
}

# Write under a temporary name, then rename, so WinSCP never uploads a half-written file.
function Export-To($SqlFile, $Name, [switch]$NoHeader) {
  $tmp = Join-Path $OutDir "$Name.tmp"
  Export-Query $SqlFile $tmp -NoHeader:$NoHeader
  if (Test-Path $tmp) { Move-Item $tmp (Join-Path $OutDir $Name) -Force }
}

Export-To "$Root\sql\po_lines.sql"      "FPS_PO_LINES_$stamp.csv" -NoHeader
Export-To "$Root\sql\invoice_dates.sql" "FPS_INVOICE_DATES_$stamp.csv"
Export-To "$Root\sql\freight_detail.sql" "FPS_FREIGHT_DETAIL_$stamp.csv"

Get-ChildItem "$Root\logs" | Where-Object LastWriteTime -lt (Get-Date).AddDays(-30) | Remove-Item
Stop-Transcript
```

### WinSCP (your existing server)

Add a transfer that uploads `FPS_*.csv` from `$OutDir` to `/Imports` on the PDI FTP and removes each file once it's
uploaded (`put -delete`, or move it to an archive folder), scheduled a little after the export, e.g. **1:45 AM**.
Leave out `*.tmp`. A file that doesn't upload just waits for the next run; the app imports waiting files oldest first.

## 3. Schedule it

SQL Server Agent → Jobs → New Job "FPS Team nightly export":

- Step: type **Operating system (CmdExec)**, command
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\fps\pdi-export\export.ps1`
- The step runs as the Agent service account (or a proxy): it needs read access to the PDI database and
  write access to `C:\fps\pdi-export` and `$OutDir` (for a share, use a domain account as the proxy). A read-only login is enough: the script only runs SELECTs.
- Schedule: daily, **1:30 AM**.
- Notifications: email an operator **when the job fails**.

(Windows Task Scheduler running the same command works too.)

Test once by hand: run the job, check the files appear in `$OutDir`, run the WinSCP transfer, check they arrived
on FTP, then in FPS Team go to Admin → Automated
Processes → PDI PO Lines Sync / PDI Invoice Dates Sync → **Run now** and read the log.

## 4. Turn on the app side

Admin → Automated Processes, set both schedules (they start Off):

- PDI PO Lines Sync: `30 2 * * * America/New_York`
- PDI Invoice Dates Sync: `30 2 * * * America/New_York`
- PDI Freight Detail Sync: `45 2 * * * America/New_York` (after the PDI Fuel Load Sync at 2:30)

Once these run nightly, the manual Data Imports pages are only needed for one-off history loads.
