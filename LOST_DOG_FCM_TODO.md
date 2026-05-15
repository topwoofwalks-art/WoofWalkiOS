# iOS — Lost Dog FCM subscription (Bug 7 from LOST_DOG_AUDIT.md)

Deferred from the 2026-05-13 audit because iOS work needs:
- Local Xcode (this dev machine doesn't have it)
- Apple Developer Account configuration (APNs certs)
- iOS device for FCM testing
- New entitlements / capability changes

Android-side equivalent is wired (`MapViewModel.loadNearbyLostDogs` calls
`NotificationService.subscribeToLocationBasedTopics`). iOS needs the
same coverage to receive lost-dog push notifications.

## What's needed

### 1. Add FirebaseMessaging dependency to the iOS app

`Package.swift` or Podfile — add Firebase/Messaging.

### 2. Add APNs capability + entitlement

In Xcode:
- Target → Signing & Capabilities → + Capability → Push Notifications
- Add `aps-environment: development` (and `production` for release)
- Upload APNs Auth Key (or APNs cert) to Firebase Console → Cloud Messaging → iOS app configuration

### 3. Hook FCM token registration in WoofWalkApp / AppDelegate

```swift
import FirebaseMessaging
import UserNotifications

// In WoofWalkApp init or AppDelegate.didFinishLaunching:
FirebaseApp.configure()
Messaging.messaging().delegate = appDelegate    // implement MessagingDelegate
UNUserNotificationCenter.current().delegate = appDelegate
UIApplication.shared.registerForRemoteNotifications()
```

### 4. Implement MessagingDelegate

```swift
extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken token: String?) {
        // Persist token to /fcm_tokens/{uid} doc just like Android
        // (so per-user pushes work), AND trigger initial location-based
        // topic subscription if we have a cached location.
    }
}
```

### 5. Add subscribeToLocationBasedTopics equivalent

Mirror the Android `NotificationService.subscribeToLocationBasedTopics`:

```swift
extension NotificationService {
    func subscribeToLocationBasedTopics(lat: Double, lng: Double) async {
        let geohash = GeoHashUtil.encode(lat: lat, lng: lng, precision: 5)
        let topics = ["lost_dogs_\(geohash)", "events_\(geohash)"]
        for topic in topics {
            do {
                try await Messaging.messaging().subscribe(toTopic: topic)
                print("[FCM] Subscribed to \(topic)")
            } catch {
                print("[FCM] Failed to subscribe to \(topic): \(error)")
            }
        }
    }
}
```

### 6. Wire the call into MapViewModel

In `Views/Map/MapViewModel.swift`, after the first location lock is
obtained (same trigger point as Android's `loadNearbyLostDogs`):

```swift
Task {
    await NotificationService.shared.subscribeToLocationBasedTopics(
        lat: location.coordinate.latitude,
        lng: location.coordinate.longitude
    )
}
```

### 7. Add handler for the FCM data messages

When a `type=lost_dog_alert` or `type=lost_dog_found` push arrives, the
iOS notification handler should:
- For `lost_dog_alert`: show the alert with the dog name, photo, last-seen
- For `lost_dog_found`: surface a "good news" notification + remove any
  previously-shown alert for the same `lostDogId` from the notification
  centre

Mirror the Android logic in `WoofWalkMessagingService.handleLostDogAlert`.

## Test

Same two-phone runbook as Android:
1. iPhone A subscribes (move it to Manchester via Xcode location sim or
   real travel)
2. iPhone B reports a lost dog from Manchester
3. iPhone A should receive the push within 60s
4. Mark as found on B → A should receive the "found" follow-up

## Time estimate

~1 day for an iOS engineer with Xcode and an APNs-provisioned device.
