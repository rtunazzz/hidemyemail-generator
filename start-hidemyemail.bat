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
echo HideMyEmail Generator / iCloud 隐藏邮箱工具
echo.
echo 1. 生成隐藏邮箱 / Generate emails
echo 2. 查看使用中地址 / List active emails
echo 3. 查看已停用地址 / List inactive emails
echo 4. 管理 iCloud Cookie / Manage iCloud cookie
echo 5. 本地收件台和验证码 / Local inbox and codes
echo 6. 退出 / Exit
echo.
set /p choice="请选择 / Choose an option [1-6]: "

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
set /p label="标签 / Label for generated emails: "
if "%label%"=="" set "label=generated"
set /p count="生成数量 / How many emails to generate [1]: "
if "%count%"=="" set "count=1"
echo.
uv run hidemyemail generate --label "%label%" --count %count% --cookie-file cookies.txt --output emails.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] 生成失败 / Generate command failed.
echo.
pause
goto menu

:list_active
call :ensure_cookies
if errorlevel 1 goto menu
echo.
uv run hidemyemail list --active --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] 查看使用中地址失败 / List active command failed.
echo.
pause
goto menu

:list_inactive
call :ensure_cookies
if errorlevel 1 goto menu
echo.
uv run hidemyemail list --inactive --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] 查看已停用地址失败 / List inactive command failed.
echo.
pause
goto menu

:cookie_menu
cls
echo iCloud Cookie 管理 / iCloud Cookie
echo.
echo 1. 查看当前 Cookie 账号 / Show current cookie account
echo 2. 手动替换 iCloud Cookie / Replace iCloud cookie
echo 3. 自动获取 iCloud Cookie / Auto capture iCloud cookie
echo 4. 返回 / Back
echo.
set /p cookie_choice="请选择 / Choose an option [1-4]: "

if "%cookie_choice%"=="1" goto show_cookie_account
if "%cookie_choice%"=="2" goto replace_cookies
if "%cookie_choice%"=="3" goto auto_capture_cookies
if "%cookie_choice%"=="4" goto menu
goto cookie_menu

:show_cookie_account
call :has_cookies
if errorlevel 1 (
  echo.
  echo [INFO] cookies.txt 不存在或为空 / cookies.txt is missing or empty.
  echo 请使用选项 2 添加 iCloud Cookie / Use option 2 to add an iCloud cookie.
  echo.
  pause
  goto cookie_menu
)
echo.
uv run hidemyemail whoami --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] 无法识别当前 Cookie 账号 / Could not identify current cookie account.
echo.
pause
goto cookie_menu

:replace_cookies
call :show_cookie_help
pause
goto cookie_menu

:auto_capture_cookies
echo.
echo 将打开一个独立浏览器配置用于获取 Cookie。
echo This opens a separate browser profile for cookie capture.
echo 如需登录，请在浏览器中登录。工具会打开 iCloud+，点击隐藏邮件地址，
echo 捕获应用请求并保存 cookies.txt。
echo Log in if needed. The tool will open iCloud Plus, click Hide My Email,
echo capture the Hide My Email app request, and save cookies.txt.
echo.
uv run hidemyemail capture-cookie --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] 自动获取 Cookie 失败 / Auto cookie capture failed.
echo.
pause
goto cookie_menu

:inbox_menu
cls
echo 本地收件台和验证码 / Local Inbox and Codes
echo.
echo 1. 配置收件邮箱 IMAP / Configure inbox IMAP account
echo 2. 同步收件箱并显示验证码 / Sync inbox and show verification codes
echo 3. 查看最近验证码 / Show recent verification codes
echo 4. 查看最近邮件 / Show recent inbox messages
echo 5. 查看未使用本地邮箱 / List unused local emails
echo 6. 标记邮箱为已使用 / Mark email as used
echo 7. 移入垃圾箱 / Move email to trash
echo 8. 同步 iCloud 隐藏邮箱到本地库 / Sync iCloud HME addresses to local DB
echo 9. 导出 CSV 表格 / Export CSV files
echo 10. 返回 / Back
echo.
set /p inbox_choice="请选择 / Choose an option [1-10]: "

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
echo 配置用于接收转发邮件的邮箱 IMAP 账号。
echo Configure your receiving mailbox IMAP account.
echo 很多邮箱需要使用“应用专用密码”，不要用网页登录密码。
echo For many providers, use an app password instead of the normal login password.
echo 配置会保存在本地 inbox_config.json。
echo The config is saved locally in inbox_config.json.
echo.
uv run hidemyemail inbox setup
if errorlevel 1 echo [ERROR] 收件台配置失败 / Inbox setup failed.
echo.
pause
goto inbox_menu

:inbox_sync
echo.
uv run hidemyemail inbox sync --limit 100 --show-codes
if errorlevel 1 echo [ERROR] 收件箱同步失败 / Inbox sync failed.
echo.
pause
goto inbox_menu

:inbox_codes
echo.
uv run hidemyemail inbox codes --limit 30
if errorlevel 1 echo [ERROR] 无法显示验证码 / Could not show codes.
echo.
pause
goto inbox_menu

:inbox_messages
echo.
uv run hidemyemail inbox messages --limit 30
if errorlevel 1 echo [ERROR] 无法显示邮件 / Could not show messages.
echo.
pause
goto inbox_menu

:inbox_unused
echo.
uv run hidemyemail inbox addresses --state unused --limit 100
if errorlevel 1 echo [ERROR] 无法显示本地邮箱 / Could not show local emails.
echo.
pause
goto inbox_menu

:inbox_mark_used
echo.
set /p mark_email="要标记为已使用的邮箱 / Email to mark as used: "
if "%mark_email%"=="" goto inbox_menu
uv run hidemyemail inbox mark "%mark_email%" used
if errorlevel 1 echo [ERROR] 无法标记邮箱 / Could not mark email.
echo.
pause
goto inbox_menu

:inbox_mark_trash
echo.
set /p mark_email="要移入垃圾箱的邮箱 / Email to move to trash: "
if "%mark_email%"=="" goto inbox_menu
uv run hidemyemail inbox mark "%mark_email%" trash
if errorlevel 1 echo [ERROR] 无法标记邮箱 / Could not mark email.
echo.
pause
goto inbox_menu

:inbox_sync_hme
call :ensure_cookies
if errorlevel 1 goto inbox_menu
echo.
uv run hidemyemail inbox sync-hme --cookie-file cookies.txt --region %ICLOUD_REGION%
if errorlevel 1 echo [ERROR] 无法同步 iCloud 隐藏邮箱 / Could not sync iCloud HME addresses.
echo.
pause
goto inbox_menu

:inbox_export
echo.
uv run hidemyemail inbox export
if errorlevel 1 echo [ERROR] 导出失败 / Export failed.
echo.
pause
goto inbox_menu

:end
endlocal
exit /b 0

:show_cookie_help
echo.
echo 将打开 iCloud 中国页面和 cookies.txt。
echo This opens iCloud China and cookies.txt.
echo 现有 cookies.txt 不会被自动清空。
echo Existing cookies.txt will not be cleared automatically.
echo 如需替换，请在记事本中按 Ctrl+A，粘贴新的 cURL 内容，然后保存。
echo To replace it, press Ctrl+A in Notepad, paste the new cURL text, then save.
echo 打开记事本前会备份为 cookies.txt.bak。
echo A backup will be saved as cookies.txt.bak before Notepad opens.
echo.
echo 浏览器操作步骤 / Steps in your browser:
echo 1. 登录 https://www.icloud.com.cn/settings/
echo 2. 按 F12
echo 3. 点击 Network / 网络
echo 4. 刷新页面
echo 5. 在过滤框搜索 hme 或 maildomainws
echo 6. 如果看到 maildomainws 或 hme 请求，右键它
echo    如果只有其他请求，选择已登录状态下的设置页请求
echo    不要使用 feedbackws/reportStats，因为它通常缺少授权 Cookie
echo 7. 点击 Copy / 复制，然后 Copy as cURL / 复制为 cURL
echo 8. 将整段内容粘贴到 cookies.txt
echo 9. 保存并关闭记事本
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

echo [INFO] cookies.txt 不存在或为空 / cookies.txt is missing or empty.
call :show_cookie_help

set "has_cookie="
for /f "usebackq delims=" %%A in ("cookies.txt") do (
  if not defined has_cookie set "has_cookie=1"
)

if defined has_cookie exit /b 0

echo [ERROR] cookies.txt is still empty.
pause
exit /b 1
