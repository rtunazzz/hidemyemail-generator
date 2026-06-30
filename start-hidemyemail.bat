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
echo 5. Local inbox and codes
echo 6. Exit
echo.
set /p choice="Choose an option [1-6]: "

if "%choice%"=="1" goto generate
if "%choice%"=="2" goto list_active
if "%choice%"=="3" goto list_inactive
if "%choice%"=="4" goto cookie_menu
if "%choice%"=="5" goto inbox_menu
if "%choice%"=="6" goto end
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

:inbox_menu
cls
echo Local Inbox and Codes
echo.
echo 1. Configure inbox IMAP account
echo 2. Sync inbox and show verification codes
echo 3. Show recent verification codes
echo 4. Show recent inbox messages
echo 5. List unused local emails
echo 6. Mark email as used
echo 7. Move email to trash
echo 8. Sync iCloud HME addresses to local DB
echo 9. Export CSV files
echo 10. Back
echo.
set /p inbox_choice="Choose an option [1-10]: "

if "%inbox_choice%"=="1" goto inbox_setup
if "%inbox_choice%"=="2" goto inbox_sync
if "%inbox_choice%"=="3" goto inbox_codes
if "%inbox_choice%"=="4" goto inbox_messages
if "%inbox_choice%"=="5" goto inbox_unused
if "%inbox_choice%"=="6" goto inbox_mark_used
if "%inbox_choice%"=="7" goto inbox_mark_trash
if "%inbox_choice%"=="8" goto inbox_sync_hme
if "%inbox_choice%"=="9" goto inbox_export
if "%inbox_choice%"=="10" goto menu
goto inbox_menu

:inbox_setup
echo.
echo Configure your receiving mailbox IMAP account.
echo For many providers, use an app password instead of the normal login password.
echo The config is saved locally in inbox_config.json.
echo.
uv run hidemyemail inbox setup
if errorlevel 1 echo [ERROR] Inbox setup failed.
echo.
pause
goto inbox_menu

:inbox_sync
echo.
uv run hidemyemail inbox sync --limit 100 --show-codes
if errorlevel 1 echo [ERROR] Inbox sync failed.
echo.
pause
goto inbox_menu

:inbox_codes
echo.
uv run hidemyemail inbox codes --limit 30
if errorlevel 1 echo [ERROR] Could not show codes.
echo.
pause
goto inbox_menu

:inbox_messages
echo.
uv run hidemyemail inbox messages --limit 30
if errorlevel 1 echo [ERROR] Could not show messages.
echo.
pause
goto inbox_menu

:inbox_unused
echo.
uv run hidemyemail inbox addresses --state unused --limit 100
if errorlevel 1 echo [ERROR] Could not show local emails.
echo.
pause
goto inbox_menu

:inbox_mark_used
echo.
set /p mark_email="Email to mark as used: "
if "%mark_email%"=="" goto inbox_menu
uv run hidemyemail inbox mark "%mark_email%" used
if errorlevel 1 echo [ERROR] Could not mark email.
echo.
pause
goto inbox_menu

:inbox_mark_trash
echo.
set /p mark_email="Email to move to trash: "
if "%mark_email%"=="" goto inbox_menu
uv run hidemyemail inbox mark "%mark_email%" trash
if errorlevel 1 echo [ERROR] Could not mark email.
echo.
pause
goto inbox_menu

:inbox_sync_hme
call :ensure_cookies
if errorlevel 1 goto inbox_menu
echo.
uv run hidemyemail inbox sync-hme --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] Could not sync iCloud HME addresses.
echo.
pause
goto inbox_menu

:inbox_export
echo.
uv run hidemyemail inbox export
if errorlevel 1 echo [ERROR] Export failed.
echo.
pause
goto inbox_menu

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
