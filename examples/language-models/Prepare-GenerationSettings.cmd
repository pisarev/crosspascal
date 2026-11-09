@echo off
setlocal
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\prepare\bootstrap.ps1" -Example "GenerationSettings"
set "CP_PREPARE_EXIT=%errorlevel%"
if not "%CROSSPASCAL_PREPARE_NO_PAUSE%"=="1" pause
endlocal & exit /b %CP_PREPARE_EXIT%
