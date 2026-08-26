@echo off
REM ==============================================================================
REM Installs everything the NUnit tests in UnitTest1.cs need: Node.js, the Appium
REM server, and the UiAutomator2 driver, then points ANDROID_HOME at the bundled
REM platform-tools.
REM
REM automation.exe itself needs NONE of this - it drives phones through the adb in
REM this folder and never talks to Appium. Only the tests do. Note the two cannot
REM share a phone: Android gives the screen-reading connection to one program at a
REM time, so an Appium session takes it from automation.exe. Stop automation.exe
REM before running the tests, and stop the Appium server before running it again.
REM ==============================================================================
setlocal EnableDelayedExpansion

REM Capture the folder this script lives in (drive + path of %0, always ends with a backslash).
REM Must be read here at the top level: inside a called :label, %0 becomes the label, not the file.
set "SCRIPT_DIR=%~dp0"

set "NODE_VERSION=v24.18.0"
set "NODE_MSI=node-%NODE_VERSION%-x64.msi"
set "NODE_URL=https://nodejs.org/dist/%NODE_VERSION%/%NODE_MSI%"
set "NODE_DIR=%ProgramFiles%\nodejs"
set "NPM_DIR=%APPDATA%\npm"

REM Installing the Node.js MSI needs elevation. Check up front rather than failing halfway.
net session >nul 2>&1
if errorlevel 1 (
    echo ============================================
    echo ERROR: administrator rights are required.
    echo Right-click setup.cmd and choose
    echo   "Run as administrator"
    echo ============================================
    goto :end
)

echo ============================================
echo Checking Node.js...
echo ============================================
call node -v >nul 2>&1
if errorlevel 1 (
    echo Node.js not found. Downloading %NODE_MSI% ...
    call :Download "%NODE_URL%" "%TEMP%\%NODE_MSI%"
    if errorlevel 1 (
        echo.
        echo ============================================
        echo ERROR: could not download Node.js.
        echo Check the internet connection, or install it by hand from:
        echo   %NODE_URL%
        echo ============================================
        goto :end
    )

    echo Installing Node.js (this takes a minute)...
    msiexec /i "%TEMP%\%NODE_MSI%" /qn /norestart
    if errorlevel 1 (
        echo.
        echo ============================================
        echo ERROR: Node.js install failed.
        echo ============================================
        goto :end
    )

    REM npm is not on PATH in this window yet - the installer only updates it for
    REM new processes - so add both Node and the global-package folder by hand.
    set "PATH=%NODE_DIR%;%NPM_DIR%;%PATH%"
    del "%TEMP%\%NODE_MSI%" >nul 2>&1
    echo Node.js installed.
) else (
    echo Node.js is already installed. Skipping.
)

echo.
echo ============================================
echo Checking Appium...
echo ============================================
REM "appium -v" prints a version and exits 0 when installed; it fails when not on PATH.
call appium -v >nul 2>&1
if errorlevel 1 (
    echo Appium not found. Installing...
    call npm install -g appium
    if errorlevel 1 (
        echo.
        echo ============================================
        echo ERROR: Appium install failed. See output above.
        echo ============================================
        goto :end
    )
) else (
    echo Appium is already installed. Skipping.
)

echo.
echo ============================================
echo Checking UiAutomator2 driver...
echo ============================================
REM List installed drivers and look for uiautomator2; findstr exits 0 only if it is present.
call appium driver list --installed 2>&1 | findstr /i "uiautomator2" >nul
if errorlevel 1 (
    echo UiAutomator2 driver not found. Installing...
    call appium driver install uiautomator2
    if errorlevel 1 (
        echo.
        echo ============================================
        echo ERROR: UiAutomator2 driver install failed. See output above.
        echo ============================================
        goto :end
    )
) else (
    echo UiAutomator2 driver is already installed. Skipping.
)

echo.
echo ============================================
echo Setting ANDROID_HOME...
echo ============================================
call :SetAndroidHome "%SCRIPT_DIR%"

echo.
echo ============================================
echo COMPLETED: Node.js, Appium and UiAutomator2 are ready.
echo.
echo Close and reopen any command window before using
echo node / npm / appium, so the new PATH takes effect.
echo ============================================

:end
pause
goto :eof


REM ==============================================================================
REM Downloads %1 to %2. Prefers curl (bundled with Windows 10 1803 and later) and
REM falls back to PowerShell, so this works on older builds too. Progress output is
REM silenced in the PowerShell path because rendering it over a slow link can take
REM longer than the download itself.
REM ==============================================================================
:Download
setlocal
set "URL=%~1"
set "DEST=%~2"

where curl >nul 2>&1
if not errorlevel 1 (
    curl -L --fail -o "%DEST%" "%URL%"
    if not errorlevel 1 endlocal & exit /b 0
)

powershell -NoProfile -ExecutionPolicy Bypass -Command ^
  "$ProgressPreference='SilentlyContinue'; try { Invoke-WebRequest -Uri '%URL%' -OutFile '%DEST%' -UseBasicParsing; exit 0 } catch { exit 1 }"
if errorlevel 1 endlocal & exit /b 1
endlocal & exit /b 0


REM ==============================================================================
REM Sets ANDROID_HOME (and ANDROID_SDK_ROOT) to the folder this setup.cmd was run
REM from. That folder contains platform-tools\adb.exe, so Appium's uiautomator2
REM driver can locate the Android SDK tools. Takes the folder as its first argument.
REM ==============================================================================
:SetAndroidHome
setlocal
set "SDK_ROOT=%~1"
REM Drop the trailing backslash so setx doesn't choke on the \" sequence.
if "%SDK_ROOT:~-1%"=="\" set "SDK_ROOT=%SDK_ROOT:~0,-1%"
setx ANDROID_HOME "%SDK_ROOT%" >nul
setx ANDROID_SDK_ROOT "%SDK_ROOT%" >nul
echo ANDROID_HOME set to:
echo   %SDK_ROOT%
echo (Restart the app / reopen any command windows for this to take effect.)
endlocal
goto :eof
