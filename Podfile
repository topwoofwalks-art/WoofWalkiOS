platform :ios, '16.0'

use_frameworks!

target 'WoofWalk' do
  pod 'Firebase/Core'
  pod 'Firebase/Auth'
  pod 'Firebase/Firestore'
  pod 'Firebase/Storage'
  pod 'Firebase/Messaging'
  pod 'Firebase/Crashlytics'
  pod 'Firebase/Analytics'

  pod 'GoogleSignIn'
  pod 'GoogleMaps'
  pod 'GooglePlaces'

  pod 'Alamofire'
  pod 'Kingfisher'
end

post_install do |installer|
  installer.pods_project.targets.each do |target|
    target.build_configurations.each do |config|
      config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '16.0'
    end
  end
end
