@echo off
setlocal enabledelayedexpansion

echo =========================================
echo WoofWalk iOS - Firebase Setup
echo =========================================
echo.

set PROJECT_ID=woofwalk-e0231
set BUNDLE_ID=com.woofwalk.ios
set APP_NAME=WoofWalk iOS

echo Step 1: Checking Firebase CLI...
where firebase >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Firebase CLI not installed!
    echo Install with: npm install -g firebase-tools
    exit /b 1
)
echo [OK] Firebase CLI found
echo.

echo Step 2: Checking authentication...
firebase projects:list >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Not logged in. Running firebase login...
    firebase login
    if %ERRORLEVEL% NEQ 0 (
        echo [ERROR] Login failed!
        exit /b 1
    )
)
echo [OK] Authenticated
echo.

echo Step 3: Checking if iOS app already exists...
firebase apps:list --project %PROJECT_ID% 2>&1 | findstr /i "%BUNDLE_ID%" >nul
if %ERRORLEVEL% EQU 0 (
    echo [OK] iOS app already registered!
    echo.
    echo Step 4: Downloading GoogleService-Info.plist...
    echo Please download manually from:
    echo https://console.firebase.google.com/project/%PROJECT_ID%/settings/general
    echo.
    echo 1. Click the iOS app
    echo 2. Click "Download GoogleService-Info.plist"
    echo 3. Save to: WoofWalk\GoogleService-Info.plist
) else (
    echo No iOS app found. Creating iOS app...
    firebase apps:create --project %PROJECT_ID% ios %BUNDLE_ID% --display-name "%APP_NAME%"
    if %ERRORLEVEL% EQU 0 (
        echo [OK] iOS app created
        echo.
        echo Step 4: Downloading GoogleService-Info.plist...
        echo Please download manually from:
        echo https://console.firebase.google.com/project/%PROJECT_ID%/settings/general
        echo.
        echo 1. Click the iOS app
        echo 2. Click "Download GoogleService-Info.plist"
        echo 3. Save to: WoofWalk\GoogleService-Info.plist
    ) else (
        echo [ERROR] Failed to create iOS app
        echo Try manually at: https://console.firebase.google.com/project/%PROJECT_ID%/overview
        exit /b 1
    )
)

echo.
echo Step 5: Installing CocoaPods dependencies...
where pod >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] CocoaPods not installed!
    echo Install with: sudo gem install cocoapods
    exit /b 1
)

echo Running pod install...
pod install
if %ERRORLEVEL% EQU 0 (
    echo [OK] CocoaPods installed
) else (
    echo [ERROR] Pod install failed
    exit /b 1
)

echo.
echo =========================================
echo Setup Complete!
echo =========================================
echo.
echo Next steps:
echo 1. Download GoogleService-Info.plist from Firebase Console if not done
echo 2. Open WoofWalk.xcworkspace (NOT .xcodeproj)
echo 3. In Xcode: Select target -^> Signing ^& Capabilities
echo 4. Select your development team
echo 5. Build and run on simulator or device
echo.
echo Files created:
echo   [OK] WoofWalk\secrets.plist (Google Maps key)
if exist "WoofWalk\GoogleService-Info.plist" (
    echo   [OK] WoofWalk\GoogleService-Info.plist (Firebase config)
) else (
    echo   [!] WoofWalk\GoogleService-Info.plist (download manually)
)
echo   [OK] Pods\ (CocoaPods dependencies)
echo.
pause
