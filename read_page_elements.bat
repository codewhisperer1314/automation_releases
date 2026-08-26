@echo off
REM ==============================================================================
REM Prints the page elements of whatever screen the connected phone is showing right
REM now, straight to this window - class, text, bounds, clickable, resource-id and
REM the rest, for every element. Nothing is saved to disk.
REM
REM Get the app onto the screen you want, then double-click this file. To keep a copy
REM of the output, run it from a command window instead:
REM     read_page_elements.bat > elements.txt
REM ==============================================================================
setlocal
"%~dp0automation.exe" elements
echo.
pause
endlocal
