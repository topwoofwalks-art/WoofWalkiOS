# iOS Authentication Setup Checklist

## Pre-Implementation Setup

### 1. Firebase Configuration
- [ ] Add GoogleService-Info.plist to Xcode project
- [ ] Verify Firebase project matches Android app
- [ ] Enable Email/Password authentication in Firebase Console
- [ ] Enable Google Sign-In in Firebase Console
- [ ] Configure OAuth consent screen

### 2. Xcode Project Configuration
- [ ] Add FirebaseAuth package dependency
- [ ] Add FirebaseFirestore package dependency
- [ ] Add GoogleSignIn package dependency
- [ ] Enable "Sign in with Apple" capability
- [ ] Enable "Keychain Sharing" capability
- [ ] Add Face ID usage description to Info.plist:
```xml
<key>NSFaceIDUsageDescription</key>
<string>Use Face ID to quickly sign in to WoofWalk</string>
```

### 3. Google Sign-In Setup
- [ ] Download OAuth client ID from Firebase Console
- [ ] Add URL scheme to Info.plist:
```xml
<key>CFBundleURLTypes</key>
<array>
    <dict>
        <key>CFBundleURLSchemes</key>
        <array>
            <string>YOUR_REVERSED_CLIENT_ID</string>
        </array>
    </dict>
</array>
```

### 4. Apple Sign-In Setup
- [ ] Add "Sign in with Apple" entitlement
- [ ] Configure App ID with Sign in with Apple
- [ ] Register service ID in Apple Developer Portal
- [ ] Add service ID to Firebase Console

## File Integration Steps

### 1. Add Service Files
- [x] Copy AuthService.swift to Services folder
- [x] Copy KeychainManager.swift to Utils folder
- [x] Copy BiometricAuthManager.swift to Utils folder
- [ ] Add files to Xcode project target

### 2. Add ViewModel Files
- [x] Copy AuthViewModel.swift to ViewModels folder
- [ ] Add file to Xcode project target

### 3. Add View Files
- [x] Copy LoginView.swift to Views/Auth folder
- [x] Copy SignupView.swift to Views/Auth folder
- [x] Copy ForgotPasswordView.swift to Views/Auth folder
- [x] Copy OnboardingView.swift to Views/Auth folder
- [x] Copy CustomTextField.swift to Views/Components folder
- [ ] Add all files to Xcode project target

### 4. Update Main App
- [ ] Import FirebaseCore in AppDelegate or App struct
- [ ] Configure Firebase in app initialization:
```swift
import FirebaseCore

@main
struct WoofWalkApp: App {
    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

### 5. Implement Navigation
- [ ] Create auth routing logic
- [ ] Add navigation from onboarding to login
- [ ] Add navigation from login to signup
- [ ] Add navigation from login to forgot password
- [ ] Add navigation on successful authentication

## Testing Checklist

### Email/Password Authentication
- [ ] Sign up with valid email and password
- [ ] Sign up with invalid email (verify error)
- [ ] Sign up with weak password (verify error)
- [ ] Sign up with existing email (verify error)
- [ ] Sign in with valid credentials
- [ ] Sign in with invalid credentials (verify error)
- [ ] Sign in with non-existent account (verify error)
- [ ] Password confirmation mismatch (verify error)

### Google Sign In
- [ ] First-time Google sign in creates account
- [ ] Returning Google user signs in successfully
- [ ] Google sign in cancellation handled gracefully
- [ ] Network error during Google sign in handled

### Apple Sign In
- [ ] First-time Apple sign in creates account
- [ ] Returning Apple user signs in successfully
- [ ] Apple sign in cancellation handled gracefully
- [ ] Privacy options respected (hide email)

### Biometric Authentication
- [ ] Face ID prompt appears correctly
- [ ] Touch ID prompt appears correctly
- [ ] Biometric success logs in user
- [ ] Biometric failure shows error
- [ ] Credentials saved after successful login
- [ ] Biometric button only shows when available

### Password Reset
- [ ] Valid email sends reset link
- [ ] Invalid email shows error
- [ ] Success message displayed
- [ ] Firebase reset email received

### Session Management
- [ ] User stays logged in after app restart
- [ ] Sign out clears all credentials
- [ ] Sign out clears Keychain data
- [ ] Token refresh works automatically

### Input Validation
- [ ] Email format validated in real-time
- [ ] Username minimum length enforced
- [ ] Password minimum length enforced
- [ ] Confirm password matches password
- [ ] Error messages clear when input changes

### UI/UX
- [ ] Loading states show during authentication
- [ ] Error messages display correctly
- [ ] Success navigation occurs
- [ ] Buttons disabled during loading
- [ ] Back navigation works correctly
- [ ] Onboarding skippable
- [ ] Keyboard dismisses appropriately

## Security Verification

### Keychain
- [ ] Tokens stored in Keychain only
- [ ] Credentials encrypted in Keychain
- [ ] Keychain data cleared on sign out
- [ ] Keychain accessible only when unlocked

### Biometric
- [ ] Biometric required before credential access
- [ ] Failed biometric doesn't expose credentials
- [ ] Biometric lockout handled gracefully

### Network
- [ ] All Firebase calls use HTTPS
- [ ] API keys not exposed in client code
- [ ] No sensitive data in logs

### Code
- [ ] No hardcoded credentials
- [ ] No passwords in plain text
- [ ] Error messages don't leak sensitive info
- [ ] Input sanitized before submission

## Production Readiness

### Configuration
- [ ] Firebase production project configured
- [ ] Google OAuth production credentials
- [ ] Apple Sign In production service ID
- [ ] Analytics configured (optional)
- [ ] Crashlytics configured (optional)

### App Store Requirements
- [ ] Privacy policy URL added
- [ ] Terms of service URL added
- [ ] App Store Connect app configured
- [ ] Sign in with Apple entitlement enabled
- [ ] Data usage descriptions complete

### User Experience
- [ ] Onboarding experience finalized
- [ ] Error messages user-friendly
- [ ] Loading indicators smooth
- [ ] Navigation flow intuitive
- [ ] Accessibility tested

## Known Limitations

1. **Email Verification**: Not enforced (can be added)
2. **Multi-Factor Auth**: Not implemented (future enhancement)
3. **Phone Auth**: Not included (can be added)
4. **Account Deletion**: Implemented but requires re-authentication
5. **Password Strength**: Basic validation only (can be enhanced)
6. **Session Timeout**: Relies on Firebase default (1 hour)

## Troubleshooting Guide

### Google Sign In Not Working
1. Verify GoogleService-Info.plist is in project
2. Check reversed client ID in URL schemes
3. Verify OAuth client ID in Google Cloud Console
4. Check bundle identifier matches Firebase

### Apple Sign In Not Working
1. Verify capability is enabled
2. Check App ID has Sign in with Apple
3. Verify service ID in Firebase Console
4. Check bundle identifier matches service ID

### Biometric Not Available
1. Check device has biometric hardware
2. Verify user has enrolled biometric
3. Check usage description in Info.plist
4. Verify LocalAuthentication framework imported

### Keychain Errors
1. Enable Keychain Sharing capability
2. Check keychain access group if using
3. Verify service name is consistent
4. Clear keychain in device settings for testing

### Firebase Errors
1. Verify GoogleService-Info.plist is current
2. Check Firebase project configuration
3. Verify authentication methods enabled
4. Check network connectivity

## Support Resources

- Firebase Auth Documentation: https://firebase.google.com/docs/auth/ios/start
- Google Sign In: https://developers.google.com/identity/sign-in/ios
- Apple Sign In: https://developer.apple.com/sign-in-with-apple/
- Keychain Services: https://developer.apple.com/documentation/security/keychain_services
- Local Authentication: https://developer.apple.com/documentation/localauthentication

## Next Steps

After authentication is implemented:
1. Integrate with user profile management
2. Connect to dog profile creation
3. Link to walk tracking features
4. Enable social features for authenticated users
5. Implement offline data sync
6. Add analytics tracking
7. Set up push notifications
8. Implement deep linking
