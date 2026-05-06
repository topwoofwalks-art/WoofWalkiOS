platform :ios, '16.0'

use_frameworks!

target 'WoofWalk' do
  pod 'Firebase/Core', '~> 10.29'
  pod 'Firebase/Auth', '~> 10.29'
  pod 'Firebase/Firestore', '~> 10.29'
  pod 'Firebase/Storage', '~> 10.29'
  pod 'Firebase/Messaging', '~> 10.29'
  pod 'Firebase/Crashlytics', '~> 10.29'
  pod 'Firebase/Analytics', '~> 10.29'
  pod 'Firebase/Functions', '~> 10.29'

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
end
