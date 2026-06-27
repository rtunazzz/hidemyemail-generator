@echo off
setlocal

cd /d "%~dp0"
set "ICLOUD_REGION=china"
set "PYTHONUTF8=1"
set "PYTHONIOENCODING=utf-8"
chcp 65001 >nul

where uv >nul 2>nul
if errorlevel 1 (
  echo [ERROR] uv was not found in PATH.
  echo Install uv, then run this launcher again:
  echo   powershell -ExecutionPolicy ByPass -c "irm https://astral.sh/uv/install.ps1 | iex"
  pause
  exit /b 1
)

if not exist ".venv\" (
  echo [INFO] Creating virtual environment and installing dependencies...
  uv sync --python 3.12
  if errorlevel 1 (
    echo [ERROR] Dependency installation failed.
    pause
    exit /b 1
  )
)

:menu
cls
echo HideMyEmail Generator
echo.
echo 1. Generate emails
echo 2. List active emails
echo 3. List inactive emails
echo 4. Manage iCloud cookie
echo 5. Exit
echo.
set /p choice="Choose an option [1-5]: "

if "%choice%"=="1" goto generate
if "%choice%"=="2" goto list_active
if "%choice%"=="3" goto list_inactive
if "%choice%"=="4" goto cookie_menu
if "%choice%"=="5" goto end
goto menu

:generate
call :ensure_cookies
if errorlevel 1 goto menu
echo.
set /p label="Label for generated emails: "
if "%label%"=="" set "label=generated"
set /p count="How many emails to generate [1]: "
if "%count%"=="" set "count=1"
echo.
uv run hidemyemail generate --label "%label%" --count %count% --cookie-file cookies.txt --output emails.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] Generate command failed.
echo.
pause
goto menu

:list_active
call :ensure_cookies
if errorlevel 1 goto menu
echo.
uv run hidemyemail list --active --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] List active command failed.
echo.
pause
goto menu

:list_inactive
call :ensure_cookies
if errorlevel 1 goto menu
echo.
uv run hidemyemail list --inactive --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] List inactive command failed.
echo.
pause
goto menu

:cookie_menu
cls
echo iCloud Cookie
echo.
echo 1. Show current cookie account
echo 2. Replace iCloud cookie
echo 3. Auto capture iCloud cookie
echo 4. Back
echo.
set /p cookie_choice="Choose an option [1-4]: "

if "%cookie_choice%"=="1" goto show_cookie_account
if "%cookie_choice%"=="2" goto replace_cookies
if "%cookie_choice%"=="3" goto auto_capture_cookies
if "%cookie_choice%"=="4" goto menu
goto cookie_menu

:show_cookie_account
call :has_cookies
if errorlevel 1 (
  echo.
  echo [INFO] cookies.txt is missing or empty.
  echo Use option 2 to add an iCloud cookie.
  echo.
  pause
  goto cookie_menu
)
echo.
uv run hidemyemail whoami --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] Could not identify current cookie account.
echo.
pause
goto cookie_menu

:replace_cookies
call :show_cookie_help
pause
goto cookie_menu

:auto_capture_cookies
echo.
echo This opens a separate browser profile for cookie capture.
echo Log in if needed. The tool will open iCloud Plus, click Hide My Email,
echo capture the Hide My Email app request, and save cookies.txt.
echo.
uv run hidemyemail capture-cookie --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] Auto cookie capture failed.
echo.
pause
goto cookie_menu

:end
endlocal
exit /b 0

:show_cookie_help
echo.
echo This opens iCloud China and cookies.txt.
echo Existing cookies.txt will not be cleared automatically.
echo To replace it, press Ctrl+A in Notepad, paste the new cURL text, then save.
echo A backup will be saved as cookies.txt.bak before Notepad opens.
echo.
echo Steps in your browser:
echo 1. Log in to https://www.icloud.com.cn/settings/
echo 2. Press F12
echo 3. Click Network
echo 4. Refresh the page
echo 5. Use the filter box to search hme or maildomainws
echo 6. Right-click a maildomainws or hme request if you see one
echo    If you only see other requests, choose a logged-in settings request
echo    but avoid feedbackws/reportStats because it misses auth cookies.
echo 7. Click Copy, then Copy as cURL
echo 8. Paste the whole copied text into cookies.txt
echo 9. Save and close Notepad.
echo.
if exist cookies.txt copy /y cookies.txt cookies.txt.bak >nul
if not exist cookies.txt type nul > cookies.txt
start "" "https://www.icloud.com.cn/settings/"
notepad cookies.txt
exit /b 0

:has_cookies
set "has_cookie="
if exist "cookies.txt" (
  for /f "usebackq delims=" %%A in ("cookies.txt") do (
    if not defined has_cookie set "has_cookie=1"
  )
)

if defined has_cookie exit /b 0
exit /b 1

:ensure_cookies
call :has_cookies
if not errorlevel 1 exit /b 0

echo [INFO] cookies.txt is missing or empty.
call :show_cookie_help

set "has_cookie="
for /f "usebackq delims=" %%A in ("cookies.txt") do (
  if not defined has_cookie set "has_cookie=1"
)

if defined has_cookie exit /b 0

echo [ERROR] cookies.txt is still empty.
pause
exit /b 1
