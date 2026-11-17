@echo off
cd /d "%~dp0"
title Bloom Server - keep this window open
echo ================================================
echo   Local server:  http://127.0.0.1:8000
echo   KEEP THIS WINDOW OPEN while using the page.
echo   Open the URL above in Chrome or Edge.
echo   Close this window to stop the server.
echo ================================================
python serve.py
pause
