@echo off
setlocal
cd /d "%~dp0"

set "APK=%~dp0dist\web-ui-canvas-android.apk"
set "ADB=adb"

echo ==========================================
echo   Web UI Canvas - Android Release Build
echo ==========================================
echo.

where flutter >nul 2>nul
if errorlevel 1 (
  echo [ERROR] Flutter wurde nicht in PATH gefunden.
  goto :fail
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0tool\bootstrap_android.ps1"
if errorlevel 1 goto :fail

call flutter pub get
if errorlevel 1 goto :fail

echo.
echo [1/3] Analyse - Infos und Warnungen sind nicht fatal...
call flutter analyze --no-fatal-infos --no-fatal-warnings
if errorlevel 1 goto :fail

echo.
echo [2/3] APK bauen...
call flutter build apk --release
if errorlevel 1 goto :fail

if not exist "%~dp0dist" mkdir "%~dp0dist"
copy /Y "%~dp0build\app\outputs\flutter-apk\app-release.apk" "%APK%" >nul
if errorlevel 1 goto :fail

echo.
echo [OK] APK gebaut:
echo %APK%

echo.
echo [3/3] APK per ADB installieren...

where adb >nul 2>nul
if errorlevel 1 (
  if exist "%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe" (
    set "ADB=%LOCALAPPDATA%\Android\Sdk\platform-tools\adb.exe"
  ) else if defined ANDROID_HOME if exist "%ANDROID_HOME%\platform-tools\adb.exe" (
    set "ADB=%ANDROID_HOME%\platform-tools\adb.exe"
  ) else if defined ANDROID_SDK_ROOT if exist "%ANDROID_SDK_ROOT%\platform-tools\adb.exe" (
    set "ADB=%ANDROID_SDK_ROOT%\platform-tools\adb.exe"
  ) else (
    echo [WARNUNG] ADB wurde nicht gefunden.
    echo APK ist fertig, konnte aber nicht automatisch installiert werden.
    start "" explorer.exe /select,"%APK%"
    exit /b 0
  )
)

"%ADB%" start-server >nul 2>nul

set "ADB_DEVICE="
for /f "skip=1 tokens=1,2" %%A in ('"%ADB%" devices 2^>nul') do (
  if "%%B"=="device" if not defined ADB_DEVICE set "ADB_DEVICE=%%A"
)

if not defined ADB_DEVICE (
  echo [WARNUNG] Kein freigegebenes ADB-Device gefunden.
  echo.
  "%ADB%" devices
  echo.
  echo USB-Debugging pruefen und die ADB-Freigabe am Handy bestaetigen.
  echo APK ist trotzdem fertig gebaut.
  start "" explorer.exe /select,"%APK%"
  exit /b 0
)

echo Device: %ADB_DEVICE%
"%ADB%" -s "%ADB_DEVICE%" install -r "%APK%"
if errorlevel 1 (
  echo.
  echo [ERROR] APK wurde gebaut, aber die ADB-Installation ist fehlgeschlagen.
  echo Device: %ADB_DEVICE%
  pause
  exit /b 1
)

echo.
echo ==========================================
echo [OK] Build + Installation erfolgreich.
echo Device: %ADB_DEVICE%
echo ==========================================
exit /b 0

:fail
echo.
echo [ERROR] Android Build fehlgeschlagen.
pause
exit /b 1
