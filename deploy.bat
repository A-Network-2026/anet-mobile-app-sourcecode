@echo off
REM 🚀 Quick Deploy Script for Google Play Store (Windows)
REM Run this to prepare your app for Play Store upload

setlocal enabledelayedexpansion
cls

echo =========================================
echo    A-Network Play Store Deployment
echo =========================================
echo.

cd my_app || exit /b 1

if "%AI_BASE_URL%"=="" (
    set AI_BASE_URL=https://anetwork-ai-backend.onrender.com
)

if "%AI_SUPPORT_TOKEN%"=="" (
    if not "%ADS_SUPPORT_TOKEN%"=="" (
        set AI_SUPPORT_TOKEN=%ADS_SUPPORT_TOKEN%
    )
)

if "%AI_SUPPORT_TOKEN%"=="" (
    echo ❌ AI_SUPPORT_TOKEN is not set.
    echo Set it before running this script, for example:
    echo   set AI_SUPPORT_TOKEN=replace-with-strong-random-token
    exit /b 1
)

echo 🔐 AI build config:
echo   AI_BASE_URL=%AI_BASE_URL%
echo   AI_SUPPORT_TOKEN=***configured***
echo.

REM Step 1: Clean
echo 🧹 Step 1: Cleaning build files...
call flutter clean
echo ✅ Clean complete
echo.

REM Step 2: Get dependencies
echo 📦 Step 2: Getting dependencies...
call flutter pub get
echo ✅ Dependencies ready
echo.

REM Step 3: Analyze
echo 🔍 Step 3: Analyzing code...
call flutter analyze --fatal-infos
echo ✅ Analysis complete
echo.

REM Step 4: Build APK for testing
echo 🏗️  Step 4: Building release APK (for local testing)...
call flutter build apk --release --dart-define=AI_BASE_URL=%AI_BASE_URL% --dart-define=AI_SUPPORT_TOKEN=%AI_SUPPORT_TOKEN%
if !errorlevel! equ 0 (
    echo ✅ APK ready at: build\app\outputs\flutter-apk\app-release.apk
) else (
    echo ❌ APK build failed
    exit /b 1
)
echo.

REM Step 5: Build App Bundle for Play Store
echo 🎁 Step 5: Building App Bundle (for Play Store)...
call flutter build appbundle --release --dart-define=AI_BASE_URL=%AI_BASE_URL% --dart-define=AI_SUPPORT_TOKEN=%AI_SUPPORT_TOKEN%
if !errorlevel! equ 0 (
    echo ✅ App Bundle ready at: build\app\outputs\bundle\release\app-release.aab
) else (
    echo ❌ App Bundle build failed
    exit /b 1
)
echo.

REM Step 6: Show file locations
echo 📊 Step 6: Build artifacts ready...
echo.
echo Files created:
echo   - APK: build\app\outputs\flutter-apk\app-release.apk
echo   - Bundle: build\app\outputs\bundle\release\app-release.aab
echo.

REM Step 7: Summary
echo =========================================
echo ✅ ALL BUILD STEPS COMPLETED!
echo =========================================
echo.
echo 📋 What's Next:
echo 1. Get AdMob App ID ^& Ad Unit IDs
echo 2. Update lib\ads_service.dart with your Ad IDs
echo 3. Update android\app\src\main\AndroidManifest.xml
echo 4. Test APK locally on your device
echo 5. Create Google Play Developer Account
echo 6. Upload app-release.aab to Play Console
echo.
echo 📚 Documentation:
echo    - GOOGLE_PLAY_DEPLOYMENT.md (Full guide)
echo    - DEPLOYMENT_CHECKLIST.md (Quick checklist)
echo    - BUILD_COMMANDS.md (Reference)
echo.
echo 🚀 Ready to deploy!
echo.
pause
