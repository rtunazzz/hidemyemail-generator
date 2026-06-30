@echo off
setlocal

cd /d "%~dp0"
if not defined HIDEMYEMAIL_REGION set "HIDEMYEMAIL_REGION=global"
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

uv run python -m hidemyemail_generator.launcher
endlocal
