@echo off
title SOULMASK - WORLD SLOT

cd /d "%~dp0"

call StartServer.bat ^
-SteamServerName="CHANGE ME" ^
-MaxPlayers=4 ^
-adminpsw="CHANGE_THIS_PASSWORD" ^
-pve ^
-saving=300 ^
-backup=900 ^
-initbackup

pause

