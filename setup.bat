@echo off
rem Installs what Mimo needs, builds it, and adds a Desktop shortcut.
setlocal
title Mimo Setup
cd /d "%~dp0"

set "BASH=C:\msys64\usr\bin\bash.exe"
set "MSYSTEM=UCRT64"
set "CHERE_INVOKING=1"
set "PACKAGES=mingw-w64-ucrt-x86_64-cmake mingw-w64-ucrt-x86_64-ninja mingw-w64-ucrt-x86_64-gcc mingw-w64-ucrt-x86_64-pkgconf mingw-w64-ucrt-x86_64-libplist mingw-w64-ucrt-x86_64-gstreamer mingw-w64-ucrt-x86_64-gst-plugins-base mingw-w64-ucrt-x86_64-gst-libav mingw-w64-ucrt-x86_64-gst-plugins-good mingw-w64-ucrt-x86_64-gst-plugins-bad"

echo.
echo Mimo Setup
echo This can take 10 minutes or more, and needs about 3 GB of disk space.
echo.

if exist "%BASH%" goto msys_ready
echo [1/5] Installing MSYS2...
where winget >nul 2>nul || goto no_winget
winget install --id MSYS2.MSYS2 --exact --silent --accept-package-agreements --accept-source-agreements
if not exist "%BASH%" goto failed
:msys_ready

echo.
echo [2/5] Updating MSYS2...
rem the first update can end the shell it runs in, so it runs twice
"%BASH%" -lc "pacman -Syu --noconfirm"
"%BASH%" -lc "pacman -Syu --noconfirm" || goto failed

echo.
echo [3/5] Installing libraries...
"%BASH%" -lc "pacman -S --needed --noconfirm %PACKAGES%" || goto failed

echo.
echo [4/5] Building the receiver...
"%BASH%" -lc "mkdir -p build-fit && cd build-fit && cmake .. -G Ninja && ninja" || goto failed

echo.
echo [5/5] Building the Mimo app...
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0app\build.ps1" || goto failed
if not exist "%~dp0Mimo.exe" goto failed
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s = (New-Object -ComObject WScript.Shell).CreateShortcut([Environment]::GetFolderPath('Desktop') + '\Mimo.lnk'); $s.TargetPath = '%~dp0Mimo.exe'; $s.WorkingDirectory = '%~dp0'; $s.Save()"

echo.
echo Mimo is ready. Open it from the Mimo icon on your Desktop.
echo If Windows Firewall asks, allow Mimo on Private networks.
echo.
pause
exit /b 0

:no_winget
echo.
echo winget was not found. Install MSYS2 from https://www.msys2.org to C:\msys64, then run setup.bat again.
goto stop

:failed
echo.
echo Setup did not finish. Read the messages above, then run setup.bat again.

:stop
echo.
pause
exit /b 1
