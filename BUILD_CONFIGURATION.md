# WoofWalk iOS Build Configuration

## Build Schemes

### Debug Configuration
- **Purpose**: Development and testing
- **Optimization**: None (`-Onone`)
- **Debug Info**: Full with dwarf
- **Testability**: Enabled
- **Swift Compilation**: Individual files
- **Build Active Architecture Only**: Yes
- **Preprocessor Macros**: `DEBUG=1`

**Use for**:
- Local development
- Simulator testing
- Debug builds
- Debugging with breakpoints

### Release Configuration
- **Purpose**: App Store distribution
- **Optimization**: Whole module (`-O`)
- **Debug Info**: dwarf-with-dsym
- **Testability**: Disabled
- **Swift Compilation**: Whole module optimization
- **Build Active Architecture Only**: No
- **NS Assertions**: Disabled

**Use for**:
- TestFlight builds
- App Store submission
- Performance testing
- Production releases

## Build Settings

### Common Settings
```
IPHONEOS_DEPLOYMENT_TARGET = 16.0
SWIFT_VERSION = 5.0
PRODUCT_BUNDLE_IDENTIFIER = com.woofwalk.ios
MARKETING_VERSION = 1.0.0
CURRENT_PROJECT_VERSION = 1
```

### Signing
```
CODE_SIGN_STYLE = Automatic
DEVELOPMENT_TEAM = <Your Team ID>
```

For manual signing:
```
CODE_SIGN_IDENTITY = "Apple Development" (Debug)
CODE_SIGN_IDENTITY = "Apple Distribution" (Release)
PROVISIONING_PROFILE_SPECIFIER = <Profile Name>
```

### Capabilities Required
- Background Modes (Location updates, Remote notifications)
- Push Notifications
- Maps
- Sign in with Apple (optional)

## CocoaPods Configuration

### Podfile Settings
- Platform: iOS 16.0+
- Use frameworks: Yes
- Deployment target: 16.0

### Pod Installation
```bash
pod install
```

### Update Pods
```bash
pod update
```

### Clean and Reinstall
```bash
rm -rf Pods Podfile.lock
pod cache clean --all
pod install
```

## Build Process

### From Xcode
1. Open `WoofWalk.xcworkspace`
2. Select scheme (Debug/Release)
3. Select target device/simulator
4. Product > Build (Cmd+B)
5. Product > Run (Cmd+R)

### From Command Line
```bash
# Build for simulator
xcodebuild -workspace WoofWalk.xcworkspace \
  -scheme WoofWalk \
  -configuration Debug \
  -sdk iphonesimulator \
  -destination 'platform=iOS Simulator,name=iPhone 15'

# Build for device
xcodebuild -workspace WoofWalk.xcworkspace \
  -scheme WoofWalk \
  -configuration Release \
  -sdk iphoneos

# Archive for distribution
xcodebuild -workspace WoofWalk.xcworkspace \
  -scheme WoofWalk \
  -configuration Release \
  -archivePath ./build/WoofWalk.xcarchive \
  archive

# Export IPA
xcodebuild -exportArchive \
  -archivePath ./build/WoofWalk.xcarchive \
  -exportPath ./build \
  -exportOptionsPlist ExportOptions.plist
```

## Environment Configuration

### Development
- Use Firebase test project
- Enable verbose logging
- Mock location services for testing
- Use test API endpoints

### Production
- Use Firebase production project
- Disable debug logging
- Real location services
- Production API endpoints

### Configuration Files

#### secrets.plist (Not in version control)
```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>GOOGLE_MAPS_API_KEY</key>
    <string>YOUR_MAPS_API_KEY</string>
    <key>API_BASE_URL</key>
    <string>https://api.woofwalk.com</string>
</dict>
</plist>
```

#### GoogleService-Info.plist (Not in version control)
- Download from Firebase Console
- Add to WoofWalk target
- Different files for Debug/Release if using multiple Firebase projects

## Code Signing

### Development
- Automatic signing recommended
- Use development certificate
- Test on physical devices
- Requires Apple Developer account

### Distribution
- App Store: Use distribution certificate
- TestFlight: Same as App Store
- Ad Hoc: Distribution certificate + Ad Hoc profile
- Enterprise: Enterprise distribution certificate

### Certificates Required
- Apple Development (for development)
- Apple Distribution (for App Store)

### Provisioning Profiles
- Development profile (for testing)
- App Store profile (for distribution)
- Ad Hoc profile (for external testing)

## Optimization Settings

### Release Build Optimizations
- **Dead Code Stripping**: YES
- **Strip Debug Symbols**: YES
- **Strip Swift Symbols**: YES
- **Enable Bitcode**: NO (deprecated)
- **Optimize for Size**: NO
- **Link-Time Optimization**: YES
- **Whole Module Optimization**: YES

### Asset Optimization
- App thinning: Enabled
- On-demand resources: Optional
- Compress PNG files: YES

## Testing Configurations

### Unit Tests
- Framework: XCTest
- Run on: Simulator
- Coverage: Enabled

### UI Tests
- Framework: XCUITest
- Run on: Simulator and Device
- Screenshots: Capture failures

### Performance Tests
- Measure: Time, Memory, Storage
- Baseline: Set after implementation

## Continuous Integration

### GitHub Actions (Example)
```yaml
name: iOS CI
on: [push, pull_request]
jobs:
  build:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Install CocoaPods
        run: pod install
      - name: Build
        run: xcodebuild -workspace WoofWalk.xcworkspace -scheme WoofWalk -sdk iphonesimulator
      - name: Test
        run: xcodebuild test -workspace WoofWalk.xcworkspace -scheme WoofWalk -destination 'platform=iOS Simulator,name=iPhone 15'
```

### Fastlane (Recommended)
```ruby
# Fastfile
lane :test do
  scan(workspace: "WoofWalk.xcworkspace", scheme: "WoofWalk")
end

lane :beta do
  build_app(workspace: "WoofWalk.xcworkspace", scheme: "WoofWalk")
  upload_to_testflight
end

lane :release do
  build_app(workspace: "WoofWalk.xcworkspace", scheme: "WoofWalk")
  upload_to_app_store
end
```

## Troubleshooting

### Build Errors
- Clean build folder: Cmd+Shift+K
- Clean derived data: Cmd+Option+Shift+K
- Delete Pods and reinstall
- Restart Xcode

### Signing Issues
- Check certificate validity
- Verify provisioning profile
- Update team settings
- Check bundle identifier

### CocoaPods Issues
- Update CocoaPods: `sudo gem install cocoapods`
- Clear cache: `pod cache clean --all`
- Update repository: `pod repo update`

### Firebase Issues
- Verify GoogleService-Info.plist
- Check bundle identifier match
- Ensure file is in target
- Validate API keys

## Performance Monitoring

### Metrics to Track
- App launch time
- Memory usage
- Battery consumption
- Network performance
- Crash rate

### Tools
- Xcode Instruments
- Firebase Performance
- Firebase Crashlytics
- App Store Connect Analytics

## Version Management

### Versioning Strategy
- **Marketing Version**: User-facing (1.0.0)
- **Build Number**: Incremental (1, 2, 3...)

### Increment Build Number
```bash
agvtool next-version -all
```

### Update Marketing Version
```bash
agvtool new-marketing-version 1.0.1
```

## App Store Submission Checklist

- [ ] Update version number
- [ ] Update build number
- [ ] Set Release configuration
- [ ] Archive build
- [ ] Validate archive
- [ ] Upload to App Store Connect
- [ ] Submit for review
- [ ] Provide required screenshots
- [ ] Complete metadata
- [ ] Set pricing

## Build Artifacts

### Output Locations
- **Build**: `~/Library/Developer/Xcode/DerivedData/`
- **Archives**: `~/Library/Developer/Xcode/Archives/`
- **IPA**: Custom export path

### Archive Contents
- App binary
- dSYM files (for crash symbolication)
- BCSymbolMaps (deprecated)
- Info.plist

## Next Steps

1. Complete Firebase setup
2. Configure signing certificates
3. Install CocoaPods dependencies
4. Test Debug build on simulator
5. Test Release build on device
6. Set up CI/CD pipeline
7. Configure crash reporting
8. Enable analytics
