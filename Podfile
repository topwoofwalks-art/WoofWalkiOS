platform :ios, '16.0'

# Static linkage skips the [CP] Embed Pods Frameworks build phase
# entirely — that phase's generated script has a bash strict-mode
# bug (Pods-WoofWalk-frameworks.sh line 42 "source: unbound variable")
# that's resisted multiple workaround attempts. Static frameworks
# get linked into the main binary at compile time, so there's nothing
# to embed at runtime. Firebase 10.x, Stripe, GoogleMaps, BranchSDK
# all support static linkage. Saves ~30 MB of duplicated symbols too.
use_frameworks! :linkage => :static

target 'WoofWalk' do
  pod 'Firebase/Core', '~> 10.29'
  pod 'Firebase/Auth', '~> 10.29'
  pod 'Firebase/Firestore', '~> 10.29'
  pod 'Firebase/Storage', '~> 10.29'
  pod 'FirebaseMessaging', '~> 10.29'
  pod 'Firebase/Crashlytics', '~> 10.29'
  pod 'Firebase/Analytics', '~> 10.29'
  pod 'Firebase/Functions', '~> 10.29'

  # Firebase App Check — issues attestation tokens that the backend
  # enforces alongside Auth. Android wires
  # `PlayIntegrityAppCheckProviderFactory` in `WoofWalkApplication.kt`;
  # iOS uses `AppAttestProvider` (iOS 14+) with a `DeviceCheckProvider`
  # fallback for iOS 11-13. DEBUG builds use the debug provider so
  # simulator + dev builds aren't rejected. Without this, Firestore /
  # Functions / Storage calls fail once App Check enforcement is on.
  pod 'FirebaseAppCheck', '~> 10.29'

  pod 'GoogleSignIn', '~> 7.1'
  pod 'GoogleMaps', '~> 9.0'
  pod 'GooglePlaces', '~> 9.0'

  pod 'Alamofire', '5.8.1'
  pod 'Kingfisher', '7.11.0'

  # Stripe PaymentSheet — full PaymentSheet parity with Android. The
  # umbrella `StripePaymentSheet` pod pulls Stripe core (Stripe, StripeCore,
  # StripePayments, StripeUICore) transitively, so we don't need to list
  # each. PaymentSheet supports Stripe Connect destination charges via the
  # client_secret returned from `processBookingPayment` (the on_behalf_of
  # + transfer_data are baked into the PaymentIntent server-side).
  pod 'StripePaymentSheet', '~> 23.30'

  # Google Mobile Ads (AdMob) — rewarded-interstitial ads gate the
  # charity-points award. Mirrors Android `play-services-ads` in
  # app/build.gradle.kts. Without the user watching an ad first, walks
  # don't award charity points (the ads pay the donations).
  pod 'Google-Mobile-Ads-SDK', '~> 11.6'

  # Branch.io — iOS-side referral attribution + deferred deep-linking.
  # Equivalent of Android's Play Install Referrer API: when a user
  # clicks a `woofwalk.app/invite?ref=CODE` link and *then* installs
  # the app, Branch's first-session callback delivers the `ww_ref`
  # code to BranchReferralService, which forwards it to the
  # `attributeInstall` Cloud Function (the same CF Android calls).
  # The 3.x SDK is the modern replacement for `Branch` 2.x — module
  # name is `BranchSDK`. Plays nicely with Firebase + Stripe; no
  # known transitive conflicts with our existing pods.
  pod 'BranchSDK', '~> 3.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
      # Xcode 15.4 sandboxes user script phases by default, which
      # blocks the rsync calls in [CP] Embed Pods Frameworks from
      # reading project-root paths. Different from the earlier
      # set -u abort (handled below) — here rsync itself is denied.
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end

  # Disable sandboxing on the consuming WoofWalk target too — the
  # [CP] Embed Pods Frameworks build phase runs on the main target,
  # not on a Pods sub-target.
  installer.aggregate_targets.each do |aggregate|
    aggregate.user_project.native_targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
    aggregate.user_project.save
  end

  # Note: with use_frameworks! :linkage => :static above, no
  # Pods-WoofWalk-frameworks.sh script is generated. Previous patches
  # to that script have been removed.
end
