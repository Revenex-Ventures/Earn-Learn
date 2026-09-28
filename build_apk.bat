@echo off
REM ============================================================
REM  Earn & Learn - BUILD ONLY (make the APK, install later)
REM  Run from the repo root: C:\Users\Prashil Dalvi\Earn-Learn
REM  No phone needed. Produces a standalone release APK.
REM ============================================================
setlocal
cd /d "%~dp0"

echo.
echo ============================================================
echo   EARN ^& LEARN  -  BUILD APK (no phone required)
echo ============================================================
echo.

echo [1/4] Checking Flutter...
call flutter --version || (echo Flutter not found on PATH. Open a terminal where 'flutter' works. & pause & exit /b 1)

echo.
echo [2/4] Fetching packages...
call flutter pub get || (echo pub get failed - send me the red text. & pause & exit /b 1)

echo.
echo [3/4] Analyzing (red errors block the build; warnings/info are fine)...
call flutter analyze

echo.
echo [4/4] Building RELEASE APK (arm64 - fits all modern phones)...
call flutter build apk --release --target-platform android-arm64 || (echo BUILD FAILED - copy the red error block and send it to me. & pause & exit /b 1)

echo.
echo ============================================================
echo   BUILD SUCCEEDED
echo   APK: build\app\outputs\flutter-apk\app-release.apk
echo ============================================================
echo Opening the output folder...
start "" "build\app\outputs\flutter-apk"
echo.
echo Install later with either:
echo   - flutter run --release   (phone plugged in, USB debugging on)
echo   - or copy app-release.apk to the phone and tap Install
pause
endlocal
