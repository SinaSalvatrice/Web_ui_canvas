@echo off
setlocal
cd /d "%~dp0"

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
echo [1/2] Analyse - Infos und Warnungen sind nicht fatal...
call flutter analyze --no-fatal-infos --no-fatal-warnings
if errorlevel 1 goto :fail

echo.
echo [2/2] APK bauen...
call flutter build apk --release
if errorlevel 1 goto :fail

if not exist "%~dp0dist" mkdir "%~dp0dist"
copy /Y "%~dp0build\app\outputs\flutter-apk\app-release.apk" "%~dp0dist\web-ui-canvas-android.apk" >nul

echo.
echo [OK] APK:
echo %~dp0dist\web-ui-canvas-android.apk
start "" explorer.exe /select,"%~dp0dist\web-ui-canvas-android.apk"
exit /b 0

:fail
echo.
echo [ERROR] Android Build fehlgeschlagen.
pause
exit /b 1
