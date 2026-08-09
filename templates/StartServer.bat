@echo off
pushd "%~dp0"
if not defined SOULMASK_MAP set "SOULMASK_MAP=Level01_Main"
start WSServer.exe %SOULMASK_MAP% -server %* -log -UTF8Output -MULTIHOME=0.0.0.0 -EchoPort=18888 -forcepassthrough
popd
exit /B

