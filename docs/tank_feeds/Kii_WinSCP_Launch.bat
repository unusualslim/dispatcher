@echo off
REM =====================================================================================================
REM Kii_WinSCP_Launch.bat - copies Kii hourly tank reports to the FPS Team FTP folder /Imports.
REM
REM Kii writes one folder per day holding Report_HH.csv (HH = UTC hour). The names repeat every day, so each
REM report is staged as KII_<day folder>_<HH>.csv, then uploaded with put -delete (same as the SQL export job).
REM The app takes each reading's time from its "Last Updated Time (UTC)" column, not the file name.
REM
REM   1. Every Report_HH.csv in the Kii day folders without a marker in SENT_DIR is copied to OUT_DIR.
REM   2. WinSCP uploads OUT_DIR\KII_*.csv to /Imports and deletes each file it uploaded.
REM   3. Files that uploaded get a 0-byte marker in SENT_DIR, so they are never sent twice.
REM      A file that fails to upload stays in OUT_DIR and goes on the next run.
REM The Kii folders themselves are only read, never changed.
REM
REM First run: every report already in KII_DIR is sent. To skip the backlog, run once as
REM   Kii_WinSCP_Launch.bat seed
REM which only writes markers for what is there now (uploads nothing).
REM
REM Schedule: hourly, about 10 minutes after the hour (after Kii's report has been copied to this server).
REM NOTE: There can be no spaces after ^ symbol in the WinSCP section.
REM =====================================================================================================
setlocal EnableExtensions EnableDelayedExpansion

:[SET VARIABLES]
SET FTP_REMOTE_DIR=/
SET VENDOR=Kii
REM Folder on this server that holds Kii's day folders (each with Report_HH.csv files):
SET KII_DIR=C:\WinSCP\INBOX\Kii
SET OUT_DIR=C:\WinSCP\OUTBOX\%VENDOR%
SET SENT_DIR=C:\WinSCP\SENT\%VENDOR%
SET LOG_DIR=C:\WinSCP\LOGS\%VENDOR%

for %%P in ("%OUT_DIR%" "%SENT_DIR%" "%LOG_DIR%") do if not exist "%%~P" mkdir "%%~P"

:[STAGE NEW REPORTS]
set STAGED=0
for /d %%D in ("%KII_DIR%\*") do (
  for %%F in ("%%~fD\Report_*.csv") do (
    set "BASE=%%~nF"
    set "NAME=KII_%%~nxD_!BASE:~7!.csv"
    if not exist "%SENT_DIR%\!NAME!" if not exist "%OUT_DIR%\!NAME!" (
      if /i "%~1"=="seed" (
        type nul > "%SENT_DIR%\!NAME!"
      ) else (
        copy /y "%%~fF" "%OUT_DIR%\!NAME!" >nul && set /a STAGED+=1
      )
    )
  )
)
if /i "%~1"=="seed" (
  echo Seeded: existing reports marked as sent, nothing uploaded
  EXIT /b 0
)
echo Staged %STAGED% new report^(s^)
if not exist "%OUT_DIR%\KII_*.csv" (
  echo Nothing to upload
  EXIT /b 0
)

REM Remember what is about to go, so only files that left OUT_DIR get a marker.
dir /b "%OUT_DIR%\KII_*.csv" > "%LOG_DIR%\%VENDOR%_pending.txt"

:[WinSCP COMMAND Section]
REM *******************************************************************
REM NOTE: There can be no spaces after ^ symbol in this section
REM Use the same "open ftp://..." line as the SQL export job (Stewart_WinSCP_1_Launch.bat).
"C:\Program Files (x86)\WinSCP\WinSCP.com" ^
  /log="%LOG_DIR%\%VENDOR%_WinSCP_JOB.log" ^
  /ini="C:\WinSCP\INI\WinSCP.ini" ^
  /command ^
    "open ftp://USER:PASSWORD@ftp.perrybrothersoil.com/" ^
    "put -delete "%OUT_DIR%\KII_*.csv" /%FTP_REMOTE_DIR%/Imports/ " ^
    "exit"
REM *******************************************************************

set WINSCP_RESULT=%ERRORLEVEL%

REM put -delete removed every file that uploaded; mark those as sent (even if a later one failed).
for /f "usebackq delims=" %%N in ("%LOG_DIR%\%VENDOR%_pending.txt") do (
  if not exist "%OUT_DIR%\%%N" type nul > "%SENT_DIR%\%%N"
)

if %WINSCP_RESULT% equ 0 (
  echo Success
) else (
  echo Error - files not uploaded stay in %OUT_DIR% for the next run
)

EXIT /b %WINSCP_RESULT%
