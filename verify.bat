@echo off
setlocal

:: Load Delphi Environment if not already loaded and default path exists
if "%BDS%"=="" (
    if exist "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat" (
        call "C:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat"
    ) else (
        echo WARNING: BDS environment variable not set and default rsvars.bat not found.
    )
)

powershell.exe -ExecutionPolicy Bypass -NoProfile -File "%~dp0verify.ps1"
exit /b %ERRORLEVEL%
