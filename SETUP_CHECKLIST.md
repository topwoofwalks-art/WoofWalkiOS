# WoofWalk iOS Setup Checklist

## Prerequisites
- [ ] macOS with Xcode 15.0+ installed
- [ ] CocoaPods installed (`sudo gem install cocoapods`)
- [ ] Apple Developer Account (for device testing)
- [ ] Firebase account
- [ ] Google Cloud Console account

## Step 1: Install Dependencies
```bash
cd /mnt/c/app/WoofWalkiOS
pod install
```
Expected: `Pods` directory created, `WoofWalk.xcworkspace` generated

## Step 2: Firebase Setup
- [ ] Create Firebase project at https://console.firebase.google.com
- [ ] Add iOS app with bundle ID: `com.woofwalk.ios`
- [ ] Download `GoogleService-Info.plist`
- [ ] Add `GoogleService-Info.plist` to `WoofWalk/` directory in Xcode
- [ ] Ensure file is added to target

### Enable Firebase Services
- [ ] Authentication > Sign-in method > Email/Password (Enable)
- [ ] Authentication > Sign-in method > Google (Enable)
- [ ] Firestore Database > Create database (Start in test mode)
- [ ] Storage > Get started
- [ ] Cloud Messaging > Enable
- [ ] Crashlytics > Enable
- [ ] Analytics > Enable (automatic)

## Step 3: Google Services Configuration

### Google Sign-In
- [ ] Firebase Console > Authentication > Sign-in method > Google > Enable
- [ ] Copy OAuth client ID (iOS URL scheme)
- [ ] Add URL scheme to Info.plist if needed

### Google Maps API
- [ ] Go to Google Cloud Console (https://console.cloud.google.com)
- [ ] Enable Maps SDK for iOS
- [ ] Enable Places API
- [ ] Create API key (restrict to iOS apps)
- [ ] Create `WoofWalk/secrets.plist`:
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GOOGLE_MAPS_API_KEY</key>
    <string>YOUR_API_KEY_HERE</string>
</dict>
</plist>
```

## Step 4: Open Project
```bash
# IMPORTANT: Open .xcworkspace NOT .xcodeproj
open WoofWalk.xcworkspace
```

## Step 5: Configure Signing
- [ ] Select WoofWalk target in Xcode
- [ ] Go to Signing & Capabilities
- [ ] Select your team
- [ ] Verify bundle identifier: `com.woofwalk.ios`
- [ ] Fix any signing issues

## Step 6: Verify Build Settings
- [ ] Target: iOS 16.0+
- [ ] Swift Version: 5.0
- [ ] Build Configuration: Debug for development
- [ ] Confirm Info.plist location

## Step 7: Test Build
- [ ] Select simulator (e.g., iPhone 15)
- [ ] Press Cmd+B to build
- [ ] Fix any build errors
- [ ] Press Cmd+R to run
- [ ] App launches successfully

## Step 8: Verify Permissions
When app runs, verify Info.plist permissions appear correctly:
- [ ] Location permission dialog
- [ ] Camera permission (when accessing camera)
- [ ] Photo library permission (when accessing photos)

## Step 9: Firebase Connection Test
- [ ] Run app
- [ ] Check Xcode console for Firebase initialization
- [ ] Verify no Firebase errors
- [ ] Check Firebase Console > Project Overview for connected app

## Step 10: Next Development Steps
- [ ] Implement authentication UI
- [ ] Create user models
- [ ] Build location tracking service
- [ ] Implement map view
- [ ] Add walk tracking functionality

## Common Issues

### CocoaPods Installation Fails
```bash
# Update CocoaPods
sudo gem install cocoapods

# Clean and reinstall
rm -rf Pods Podfile.lock
pod cache clean --all
pod install
```

### Build Errors
- Clean build folder: Cmd+Shift+K
- Clean derived data: Cmd+Option+Shift+K
- Restart Xcode

### Firebase Connection Issues
- Verify `GoogleService-Info.plist` is in correct location
- Check bundle identifier matches Firebase app
- Ensure file is added to app target

### Google Maps Not Working
- Verify API key in `secrets.plist`
- Enable Maps SDK for iOS in Cloud Console
- Check API key restrictions

### Signing Issues
- Select correct development team
- Create provisioning profile if needed
- Use unique bundle identifier if required

## File Checklist

Required files created:
- [x] `WoofWalk.xcodeproj/project.pbxproj`
- [x] `WoofWalk/Info.plist`
- [x] `WoofWalk/WoofWalkApp.swift`
- [x] `WoofWalk/ContentView.swift`
- [x] `Podfile`
- [x] `.gitignore`
- [x] Directory structure (Models, Views, ViewModels, etc.)

Required files to add:
- [ ] `GoogleService-Info.plist`
- [ ] `WoofWalk/secrets.plist`

## Project Status

Current: Project structure created
Next: Install dependencies and configure Firebase
