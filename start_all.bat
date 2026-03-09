@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "BACKEND_SCRIPT=%ROOT_DIR%start_backend.bat"
set "FRONTEND_SCRIPT=%ROOT_DIR%start_frontend.bat"
set "START_DELAY_SECONDS=2"

if /i "%~1"=="-h" goto :help
if /i "%~1"=="--help" goto :help
if /i "%~1"=="--dry-run" set "DRY_RUN=1"

if not exist "%BACKEND_SCRIPT%" (
    echo [ERROR] Backend launcher not found: %BACKEND_SCRIPT%
    exit /b 1
)

if not exist "%FRONTEND_SCRIPT%" (
    echo [ERROR] Frontend launcher not found: %FRONTEND_SCRIPT%
    exit /b 1
)

echo [INFO] Backend launcher: %BACKEND_SCRIPT%
echo [INFO] Frontend launcher: %FRONTEND_SCRIPT%

if defined DRY_RUN (
    echo [DRY RUN] start "MES Backend" "%ComSpec%" /k call "%BACKEND_SCRIPT%"
    echo [DRY RUN] timeout /t %START_DELAY_SECONDS% ^>nul
    echo [DRY RUN] start "MES Frontend" "%ComSpec%" /k call "%FRONTEND_SCRIPT%"
    exit /b 0
)

echo [INFO] Opening backend window...
start "MES Backend" "%ComSpec%" /k call "%BACKEND_SCRIPT%"
timeout /t %START_DELAY_SECONDS% >nul
echo [INFO] Opening frontend window...
start "MES Frontend" "%ComSpec%" /k call "%FRONTEND_SCRIPT%"
exit /b 0

:help
echo Usage: start_all.bat [--dry-run]
echo.
echo Open backend and frontend launchers in separate windows.
echo.
echo   --dry-run  Print commands without launching them.
exit /b 0
