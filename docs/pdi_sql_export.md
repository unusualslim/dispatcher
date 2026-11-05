# Nightly PDI SQL export (PO lines + invoice dates)

A scheduled job on the PDI SQL Server writes two CSVs every night and uploads them to the PDI FTP folder
`/Imports`. FPS Team picks them up with two automated processes:

| File | App process | Layout |
|---|---|---|
| `FPS_PO_LINES_<yyyymmdd>.csv` | PDI PO Lines Sync | 56 columns, **no header**: exactly the file Data Imports → PDI Purchase Orders takes today |
| `FPS_INVOICE_DATES_<yyyymmdd>.csv` | PDI Invoice Dates Sync | Header row; columns found by name: order number, invoice date, optional invoice # and salesperson (Data Imports → PDI Invoice Dates) |

The app imports every waiting file oldest first, keeps each one on its log (Automated Processes → the process →
download), and deletes it from FTP once it imported. A file that fails stays on FTP and is retried the next night.
Other FTP jobs never touch `FPS_*.csv` names, and these jobs touch nothing else.

## 1. Folders and queries

On the SQL Server (or any Windows machine that can reach it):

```
C:\fps\pdi-export\
  sql\po_lines.sql        your PO lines query (the one you export today)
  sql\invoice_dates.sql   your invoice dates query
  out\                    files waiting to upload
  archive\                files already uploaded (keep ~30 days)
  logs\
  export.ps1              the script below
  ftp.txt                 FTP password (one line), readable only by the job's account
```

Change both queries to send a **rolling window** instead of all history. Re-sending rows is harmless (both
imports update in place), so overlap generously:

- PO lines: POs entered, changed or received in the last 14 days.
- Invoice dates: orders invoiced in the last 30 days.

Keep the PO query's 56 columns in the same order as today. Dates can stay as SQL dates: the script writes them
as `2026-11-05 00:00:00` (US-style `11/5/2026` would be misread by the PO import).

## 2. The script (`export.ps1`)

Needs the `SqlServer` PowerShell module (`Install-Module SqlServer` once, as admin) and WinSCP
(https://winscp.net, for `winscp.com`). Fill in the four settings at the top.

```powershell
$ErrorActionPreference = 'Stop'
$Server   = 'PDISQL'                 # SQL Server instance
$Database = 'PDI'                    # PDI database name
$FtpHost  = 'ftp.example.com'        # same host FPS Team uses (PDI_FTP_HOST)
$FtpUser  = 'ftpuser'                # same user (PDI_FTP_USER)
$Root     = 'C:\fps\pdi-export'
$WinScp   = 'C:\Program Files (x86)\WinSCP\WinSCP.com'

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

Export-Query "$Root\sql\po_lines.sql"      "$Root\out\FPS_PO_LINES_$stamp.csv" -NoHeader
Export-Query "$Root\sql\invoice_dates.sql" "$Root\out\FPS_INVOICE_DATES_$stamp.csv"

$files = Get-ChildItem "$Root\out\FPS_*.csv"
if ($files) {
  $pass = [uri]::EscapeDataString((Get-Content "$Root\ftp.txt" -Raw).Trim())
  $cmds = @("open ftp://$($FtpUser):$pass@$FtpHost/ -passive=on", 'cd /Imports')
  $cmds += $files | ForEach-Object { "put `"$($_.FullName)`"" }
  $cmds += 'exit'
  & $WinScp /ini=nul /log="$Root\logs\winscp_$stamp.log" /command @cmds
  if ($LASTEXITCODE -ne 0) { throw "WinSCP upload failed ($LASTEXITCODE)" }
  $files | Move-Item -Destination "$Root\archive" -Force
}

Get-ChildItem "$Root\archive", "$Root\logs" | Where-Object LastWriteTime -lt (Get-Date).AddDays(-30) | Remove-Item
Stop-Transcript
```

If an upload fails, the files stay in `out\` and go up with the next night's run (the app imports them oldest first).

## 3. Schedule it

SQL Server Agent → Jobs → New Job "FPS Team nightly export":

- Step: type **Operating system (CmdExec)**, command
  `powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\fps\pdi-export\export.ps1`
- The step runs as the Agent service account (or a proxy): it needs read access to the PDI database and
  write access to `C:\fps\pdi-export`. A read-only login is enough: the script only runs SELECTs.
- Schedule: daily, **1:30 AM**.
- Notifications: email an operator **when the job fails**.

(Windows Task Scheduler running the same command works too.)

Test once by hand: run the job, check the files arrived on FTP, then in FPS Team go to Admin → Automated
Processes → PDI PO Lines Sync / PDI Invoice Dates Sync → **Run now** and read the log.

## 4. Turn on the app side

Admin → Automated Processes, set both schedules (they start Off):

- PDI PO Lines Sync: `30 2 * * * America/New_York`
- PDI Invoice Dates Sync: `30 2 * * * America/New_York`

Once these run nightly, the manual Data Imports pages are only needed for one-off history loads.
