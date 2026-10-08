@echo off
setlocal
title Upload script to KISTROX Worker

set "WORKER=https://nirnim.ratchanon439990.workers.dev"
set "NAME=anime-dice"
set "FILE=%~dp0..\games\anime-dice.lua"
set "OUT=%TEMP%\kistrox_upload.json"

for %%A in ("%FILE%") do set "SIZE=%%~zA"

echo =====================================================
echo   Upload game script to Cloudflare KV
echo   file  : %FILE%
echo   size  : %SIZE% bytes
echo   name  : %NAME%
echo   target: %WORKER%
echo =====================================================
echo.

if not exist "%FILE%" (
  echo [ERROR] file not found: %FILE%
  echo.
  pause
  exit /b 1
)

set "ADMIN="
set /p ADMIN=Type your ADMIN_KEY then press Enter: 
if "%ADMIN%"=="" (
  echo.
  echo [CANCEL] no ADMIN_KEY entered
  echo.
  pause
  exit /b 1
)

echo.
echo Uploading %SIZE% bytes ...
echo.

curl -s -X POST "%WORKER%/admin/putscript?name=%NAME%&token=%ADMIN%" --data-binary "@%FILE%" > "%OUT%" 2>&1

findstr /c:"sent" "%OUT%" >nul 2>&1
if errorlevel 1 goto failed

echo == SUCCESS ==  script uploaded to Cloudflare KV
echo.
type "%OUT%"
echo.
del "%OUT%" >nul 2>&1
pause
exit /b 0

:failed
echo == FAILED ==  the worker replied:
echo.
type "%OUT%"
echo.
echo What to check:
echo   1. ADMIN_KEY must be exactly the same as in Cloudflare (type: Secret)
echo   2. Did you press Deploy after adding it?
echo   3. Did you already paste the new worker code and press Deploy? (step 2)
echo.
del "%OUT%" >nul 2>&1
pause
exit /b 1
