@echo off
setlocal
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0..\..\bootstrap.ps1" -Manifest "%~dp0prepare-manifest.json" -Example "VisionModels" -Device CPU %*
set "CP_PREPARE_EXIT=%errorlevel%"
if not "%CROSSPASCAL_PREPARE_NO_PAUSE%"=="1" pause
endlocal & exit /b %CP_PREPARE_EXIT%
