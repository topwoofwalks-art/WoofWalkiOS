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

  pod 'GoogleSignIn', '~> 7.1'
  pod 'GoogleMaps', '~> 9.0'
  pod 'GooglePlaces', '~> 9.0'

  pod 'Alamofire', '5.8.1'
  pod 'Kingfisher', '7.11.0'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
