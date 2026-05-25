@echo off
title DHAV Admin Dashboard
cd /d "%~dp0build\web"

echo Starting DHAV Admin Dashboard at http://localhost:8080
echo Close this window to stop the server.
echo.

start "" http://localhost:8080
python -m http.server 8080
