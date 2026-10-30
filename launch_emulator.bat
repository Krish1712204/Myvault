@echo off
title Android Emulator Launcher
echo ========================================================
echo   Cleaning stale emulator locks...
echo ========================================================
if exist "%USERPROFILE%\.android\avd\Medium_Phone.avd\hardware-qemu.ini.lock" (
    rmdir /s /q "%USERPROFILE%\.android\avd\Medium_Phone.avd\hardware-qemu.ini.lock" 2>nul
)
if exist "%USERPROFILE%\.android\avd\Medium_Phone.avd\multiinstance.lock" (
    del /f /q "%USERPROFILE%\.android\avd\Medium_Phone.avd\multiinstance.lock" 2>nul
)

echo Starting Android Emulator (Medium_Phone_API_37.0)...
echo Please wait for the phone window to appear...
echo.

"%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Medium_Phone_API_37.0 -gpu angle_indirect

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ----------------------------------------------------
    echo Retrying with default software graphics...
    "%LOCALAPPDATA%\Android\Sdk\emulator\emulator.exe" -avd Medium_Phone_API_37.0 -gpu swiftshader_indirect
)

echo.
echo Emulator process finished.
pause
