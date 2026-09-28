@echo off
REM ============================================================
REM  Earn & Learn - build a release APK and install on phone
REM  Double-click this file, or run it from a terminal in the
REM  repo root:  C:\Users\Prashil Dalvi\Earn-Learn
REM ============================================================
setlocal
cd /d "%~dp0"

echo.
echo ============================================================
echo   EARN ^& LEARN  -  BUILD ^& INSTALL
echo ============================================================
echo.

echo [1/5] Checking Flutter...
call flutter --version || (echo Flutter not found on PATH. Open a terminal where 'flutter' works. & pause & exit /b 1)

echo.
echo [2/5] Fetching packages...
call flutter pub get || (echo pub get failed. & pause & exit /b 1)

echo.
echo [3/5] Static analysis (must be clean before we ship)...
call flutter analyze
echo (If analyze printed errors above, fix those first. Warnings/info are OK.)
echo.
pause

echo.
echo [4/5] Building RELEASE APK (local flavor, no Firebase needed)...
call flutter build apk --release || (echo Build failed. Copy the red error text and send it. & pause & exit /b 1)

echo.
echo    APK built at:
echo    build\app\outputs\flutter-apk\app-release.apk
echo.

echo [5/5] Looking for a connected phone...
call flutter devices
echo.
echo    If your phone is listed above (USB debugging ON), press any
echo    key to INSTALL + LAUNCH it on the phone now.
echo    If NOT listed, see PHONE SETUP in INSTALL_ON_PHONE.md - your
echo    APK is already built at the path above and can be copied over.
echo.
pause

echo Installing and launching on the connected device...
call flutter run --release
echo.
echo Done. If it launched on your phone, you are live.
pause
endlocal
