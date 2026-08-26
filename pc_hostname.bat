@echo off
setlocal enabledelayedexpansion

:: ============================================
:: Get CPU ID
:: ============================================
set "CPUID="
for /f "skip=1 tokens=* delims=" %%A in ('wmic cpu get ProcessorId 2^>nul') do (
    if not defined CPUID (
        set "line=%%A"
        set "line=!line: =!"
        if defined line set "CPUID=!line!"
    )
)

:: ============================================
:: Get first Disk Serial Number
:: (only grabs the FIRST disk WMIC returns —
:: not guaranteed to be the boot/OS disk)
:: ============================================
set "DISKSERIAL="
for /f "skip=1 tokens=* delims=" %%A in ('wmic diskdrive get SerialNumber 2^>nul') do (
    if not defined DISKSERIAL (
        set "line=%%A"
        set "line=!line: =!"
        if defined line set "DISKSERIAL=!line!"
    )
)

if not defined CPUID (
    echo ERROR: Could not retrieve ProcessorId.
    goto :end
)
if not defined DISKSERIAL (
    echo WARNING: Disk SerialNumber came back empty ^(common on NVMe/VMs^).
)

echo CPU ID     : %CPUID%
echo Disk Serial: %DISKSERIAL%

:: ============================================
:: Combine and hash with SHA256 via certutil
:: NOTE: writing with echo adds a trailing CRLF
:: to the temp file, which affects the hash.
:: If you need this to match a hash computed
:: elsewhere (C#, PowerShell, etc.) without a
:: trailing newline, use a different write method.
:: ============================================
set "TMPFILE=%temp%\hwid_%RANDOM%.txt"
set "TMPHASH=%temp%\hash_%RANDOM%.txt"

<nul set /p "=%CPUID%%DISKSERIAL%">"%TMPFILE%"

certutil -hashfile "%TMPFILE%" SHA256 > "%TMPHASH%"

set "HASH="
for /f "skip=1 tokens=* delims=" %%H in ('type "%TMPHASH%" ^| findstr /v "CertUtil"') do (
    if not defined HASH set "HASH=%%H"
)
set "HASH=%HASH: =%"

echo.
echo HWID: %HASH%

del "%TMPFILE%" >nul 2>&1
del "%TMPHASH%" >nul 2>&1

:end
endlocal
pause
