@echo off
setlocal
set "SCRIPT=%~dp0Soulmask-Server-Manager.ps1"

powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File "%SCRIPT%"

if errorlevel 1 (
    echo.
    echo Soulmask Server Manager failed to start.
    echo.
    echo Run this command from the manager folder to see the full error:
    echo powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File ".\Soulmask-Server-Manager.ps1"
    echo.
    pause
)
endlocal

