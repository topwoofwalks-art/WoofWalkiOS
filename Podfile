platform :ios, '16.0'

use_frameworks!

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
    end
  end

  # Patch Pods-WoofWalk-frameworks.sh — CocoaPods generates an
  # install_framework() function whose `local source` is only assigned
  # inside conditional `if [ -r ... ]` branches. When SCRIPT_INPUT_FILE
  # arguments come in that don't match either condition, `${source}` is
  # referenced without being assigned and bash (running under `set -u`)
  # aborts with "source: unbound variable" at line 42. This affects
  # both CocoaPods 1.15.x and 1.16.x — the bug is in the script template.
  #
  # Fix: insert `local source=""` at the top of install_framework() so
  # the variable is always defined. The conditional `[ -r "" ]` test
  # then cleanly short-circuits when no real path was provided, instead
  # of crashing the whole embed phase.
  frameworks_script = "Pods/Target Support Files/Pods-WoofWalk/Pods-WoofWalk-frameworks.sh"
  if File.exist?(frameworks_script)
    contents = File.read(frameworks_script)
    sentinel = "local source=\"\"  # patched: avoid set -u unbound abort"
    unless contents.include?(sentinel)
      patched = contents.sub(
        /^install_framework\(\)\s*\{\n/,
        "install_framework()\n{\n  #{sentinel}\n"
      )
      if patched != contents
        File.write(frameworks_script, patched)
        puts "Patched #{frameworks_script}: init local source=\"\" in install_framework"
      end
    end
  end
end
