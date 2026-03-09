@echo off
setlocal

set "ROOT_DIR=%~dp0"
set "VENV_PYTHON=%ROOT_DIR%.venv\Scripts\python.exe"

if exist "%VENV_PYTHON%" (
    set "PYTHON_EXE=%VENV_PYTHON%"
) else (
    set "PYTHON_EXE=python"
)

"%PYTHON_EXE%" "%ROOT_DIR%start_backend.py" %*
exit /b %ERRORLEVEL%
