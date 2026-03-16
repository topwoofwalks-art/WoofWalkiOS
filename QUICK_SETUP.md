# WoofWalk iOS - Quick Setup Guide

## Automated Setup (Recommended)

I've created automated scripts that will set everything up for you!

### Option 1: Windows (Easiest)

```cmd
cd C:\app\WoofWalkiOS
setup-firebase-ios.bat
```

### Option 2: Mac/Linux or WSL

```bash
cd /mnt/c/app/WoofWalkiOS
./setup-firebase-ios.sh
```

## What the Script Does

1. ✅ **Checks Firebase CLI** - Verifies firebase-tools is installed
2. ✅ **Authenticates** - Runs `firebase login` if needed
3. ✅ **Adds iOS App** - Creates iOS app in your existing Firebase project (`woofwalk-e0231`)
4. ✅ **Downloads Config** - Attempts to download `GoogleService-Info.plist`
5. ✅ **Installs Dependencies** - Runs `pod install` for CocoaPods

## Already Created for You

✅ **secrets.plist** - Contains your Google Maps API key from Android project:
```
Location: WoofWalk/secrets.plist
API Key: AIzaSyA-13hKjKvCOZq8gpbImCPieCirXtikc78
```

## If Automatic Download Fails

The script may not be able to download `GoogleService-Info.plist` automatically. If that happens:

1. **Open Firebase Console**:
   ```
   https://console.firebase.google.com/project/woofwalk-e0231/settings/general
   ```

2. **Find iOS App**:
   - Scroll down to "Your apps"
   - Click on the iOS app (Bundle ID: `com.woofwalk.ios`)

3. **Download Config File**:
   - Click "Download GoogleService-Info.plist" button
   - Save to: `C:\app\WoofWalkiOS\WoofWalk\GoogleService-Info.plist`

## After Setup

1. **Open Workspace** (important!):
   ```
   open WoofWalk.xcworkspace
   ```
   ⚠️ **NOT** `WoofWalk.xcodeproj` - must use `.xcworkspace`

2. **Configure Code Signing**:
   - In Xcode, select WoofWalk target
   - Go to "Signing & Capabilities" tab
   - Select your Apple Developer Team

3. **Build and Run**:
   - Select a simulator or connected device
   - Press Cmd+R or click the Play button

## What's Shared with Android

✅ **Same Firebase Project**: `woofwalk-e0231`
✅ **Same Database**: Firestore data syncs between iOS and Android
✅ **Same Users**: Authentication works across platforms
✅ **Same Storage**: Firebase Storage buckets shared
✅ **Same API Key**: Using your Android Google Maps key (can create separate later)

## Files You'll Have

```
WoofWalkiOS/
├── WoofWalk/
│   ├── GoogleService-Info.plist   ← Firebase config (download if missing)
│   └── secrets.plist               ← Google Maps key (already created ✓)
├── Podfile                         ← CocoaPods dependencies
├── Pods/                           ← Installed after pod install
└── WoofWalk.xcworkspace            ← Open this in Xcode!
```

## Troubleshooting

### Firebase CLI Not Found
```bash
npm install -g firebase-tools
```

### CocoaPods Not Found
```bash
sudo gem install cocoapods
```

### Pod Install Fails
```bash
cd /mnt/c/app/WoofWalkiOS
pod repo update
pod install --verbose
```

### Can't Login to Firebase
- Run: `firebase login --no-localhost`
- Follow the browser authentication flow
- Copy the code back to terminal

## Next Steps

Once setup is complete:
1. Open `WoofWalk.xcworkspace` in Xcode
2. Select your development team for code signing
3. Build and run on simulator
4. Test the app!

---

**Need Help?** Check the full documentation in `README.md` or `SETUP_CHECKLIST.md`
