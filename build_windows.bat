@echo off
setlocal EnableExtensions
cd /d "%~dp0"

title Web UI Canvas - Windows Release Build

echo.
echo ============================================
echo   WEB UI CANVAS - WINDOWS RELEASE BUILD
echo ============================================
echo.

if not exist "pubspec.yaml" (
  echo [FEHLER] pubspec.yaml nicht gefunden.
  echo Starte diese BAT aus dem Web_ui_canvas Projektordner.
  goto :fail
)

where flutter >nul 2>nul
if errorlevel 1 (
  echo [FEHLER] Flutter wurde nicht im PATH gefunden.
  goto :fail
)

if /I "%~1"=="clean" (
  echo [1/7] Flutter Clean...
  call flutter clean
  if errorlevel 1 goto :fail
) else (
  echo [1/7] Clean uebersprungen. Fuer Clean-Build: build_windows.bat clean
)

if not exist "windows\CMakeLists.txt" (
  echo [2/7] Windows-Host fehlt - wird erzeugt...
  if not exist "tool\bootstrap_windows.ps1" (
    echo [FEHLER] tool\bootstrap_windows.ps1 nicht gefunden.
    goto :fail
  )
  powershell -NoProfile -ExecutionPolicy Bypass -File "tool\bootstrap_windows.ps1"
  if errorlevel 1 goto :fail
) else (
  echo [2/7] Windows-Host vorhanden.
)

echo [3/7] Pakete laden...
call flutter pub get
if errorlevel 1 goto :fail

echo [4/7] Code analysieren...
call flutter analyze
if errorlevel 1 (
  echo.
  echo [FEHLER] flutter analyze meldet Fehler. Build abgebrochen.
  goto :fail
)

echo [5/7] Tests ausfuehren...
call flutter test
if errorlevel 1 (
  echo.
  echo [FEHLER] Tests fehlgeschlagen. Build abgebrochen.
  goto :fail
)

echo [6/7] Windows Release bauen...
call flutter build windows --release
if errorlevel 1 goto :fail

set "RELEASE_DIR=build\windows\x64\runner\Release"
if not exist "%RELEASE_DIR%\web_ui_canvas.exe" (
  set "RELEASE_DIR=build\windows\runner\Release"
)

if not exist "%RELEASE_DIR%\web_ui_canvas.exe" (
  echo [FEHLER] Release-EXE wurde nach dem Build nicht gefunden.
  goto :fail
)

echo [7/7] Release paketieren...
if exist "dist\Web_UI_Canvas" rmdir /s /q "dist\Web_UI_Canvas"
mkdir "dist\Web_UI_Canvas" >nul
xcopy "%RELEASE_DIR%\*" "dist\Web_UI_Canvas\" /E /I /Y /Q >nul
if errorlevel 1 goto :fail

if exist "dist\Web_UI_Canvas.zip" del /q "dist\Web_UI_Canvas.zip"
powershell -NoProfile -ExecutionPolicy Bypass -Command "Compress-Archive -Path 'dist\Web_UI_Canvas\*' -DestinationPath 'dist\Web_UI_Canvas.zip' -Force"
if errorlevel 1 goto :fail

echo.
echo ============================================
echo   BUILD ERFOLGREICH
echo ============================================
echo.
echo EXE:
echo   %CD%\dist\Web_UI_Canvas\web_ui_canvas.exe
echo.
echo ZIP:
echo   %CD%\dist\Web_UI_Canvas.zip
echo.
explorer "%CD%\dist"
goto :end

:fail
echo.
echo ============================================
echo   BUILD FEHLGESCHLAGEN
echo ============================================
echo.
echo Siehe Fehlermeldung oben.
pause
exit /b 1

:end
pause
exit /b 0
