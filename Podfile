platform :ios, '16.0'

use_frameworks!

target 'WoofWalk' do
  pod 'Firebase/Core', '~> 10.20.0'
  pod 'Firebase/Auth', '~> 10.20.0'
  pod 'Firebase/Firestore', '~> 10.20.0'
  pod 'Firebase/Storage', '~> 10.20.0'
  pod 'Firebase/Messaging', '~> 10.20.0'
  pod 'Firebase/Crashlytics', '~> 10.20.0'
  pod 'Firebase/Analytics', '~> 10.20.0'

  pod 'GoogleSignIn', '~> 7.1.0'
  pod 'GoogleMaps', '~> 8.4.0'
  pod 'GooglePlaces', '~> 8.4.0'

  pod 'Alamofire', '~> 5.9.0'
  pod 'Kingfisher', '~> 7.11.0'

  target 'WoofWalkTests' do
    inherit! :search_paths
  end
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
