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
      # Xcode 15.4 sandboxes user script phases by default — disable
      # so our custom embed-frameworks script (below) can rsync.
      config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
    end
  end
  installer.aggregate_targets.each do |aggregate|
    aggregate.user_project.native_targets.each do |target|
      target.build_configurations.each do |config|
        config.build_settings['ENABLE_USER_SCRIPT_SANDBOXING'] = 'NO'
      end
    end
    aggregate.user_project.save
  end

  # OVERWRITE Pods-WoofWalk-frameworks.sh with a minimal, bash-strict-
  # safe script. The CocoaPods-generated install_framework() function
  # has `local source` declared only inside conditional branches, so
  # under `set -u` an unmatched branch leaves `${source}` unbound and
  # aborts at line 42. Multiple patches to the generated script have
  # either failed to fix it or introduced an infinite-rsync hang.
  #
  # Our replacement just rsyncs every .framework that CocoaPods
  # built into the embed location. No conditional branches, no
  # SCRIPT_INPUT_FILE iteration, no chance of unbound vars.
  frameworks_script = "Pods/Target Support Files/Pods-WoofWalk/Pods-WoofWalk-frameworks.sh"
  if File.exist?(frameworks_script)
    File.write(frameworks_script, <<~SH)
      #!/bin/sh
      # Custom embed-frameworks — replaces the buggy CocoaPods script.
      # Rsyncs every .framework that CocoaPods built into the
      # app's Frameworks/ folder. See Podfile post_install for context.
      set -e
      set -o pipefail

      if [ -z "${TARGET_BUILD_DIR:-}" ]; then
        echo "Custom embed: TARGET_BUILD_DIR unset, exiting cleanly"
        exit 0
      fi
      if [ -z "${FRAMEWORKS_FOLDER_PATH:-}" ]; then
        echo "Custom embed: FRAMEWORKS_FOLDER_PATH unset, exiting cleanly"
        exit 0
      fi
      if [ -z "${BUILT_PRODUCTS_DIR:-}" ]; then
        echo "Custom embed: BUILT_PRODUCTS_DIR unset, exiting cleanly"
        exit 0
      fi

      DEST="${TARGET_BUILD_DIR}/${FRAMEWORKS_FOLDER_PATH}"
      mkdir -p "$DEST"

      echo "Custom embed: copying frameworks from ${BUILT_PRODUCTS_DIR} to ${DEST}"

      # Each pod's framework is at BUILT_PRODUCTS_DIR/<PodName>/<Module>.framework
      find "${BUILT_PRODUCTS_DIR}" -mindepth 2 -maxdepth 2 -name "*.framework" -type d | while read -r framework; do
        [ -e "$framework" ] || continue
        name=$(basename "$framework")
        echo "  embedding $name"
        rsync -av --delete --filter='- CVS/' --filter='- .svn/' --filter='- .git/' --filter='- .hg/' --filter='- Headers' --filter='- PrivateHeaders' --filter='- Modules' "$framework" "$DEST/"
        # Strip non-arm64 slices for App Store submission.
        binary="$DEST/$name/$(basename "$name" .framework)"
        if [ -f "$binary" ] && [ "${CONFIGURATION:-}" != "Debug" ]; then
          archs=$(lipo -archs "$binary" 2>/dev/null || true)
          for slice in $archs; do
            if [ "$slice" != "arm64" ]; then
              lipo -remove "$slice" -output "$binary" "$binary" || true
            fi
          done
        fi
      done

      echo "Custom embed: done"
    SH
    puts "Replaced #{frameworks_script} with minimal custom embed script"
  end
end
