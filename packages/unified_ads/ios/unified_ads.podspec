#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint unified_ads.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'unified_ads'
  s.version          = '1.0.0'
  s.summary          = 'Core of the unified_ads Flutter plugin.'
  s.description      = <<-DESC
Core of the unified_ads Flutter plugin (no ad SDKs; ATT helper only).
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'unified_ads/Sources/unified_ads/**/*'
  s.dependency 'Flutter'
  # ATT (iOS 14+) is weak-linked so the plugin still loads on iOS 13.
  s.weak_frameworks = 'AppTrackingTransparency'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # If your plugin requires a privacy manifest, for example if it uses any
  # required reason APIs, update the PrivacyInfo.xcprivacy file to describe your
  # plugin's privacy impact, and then uncomment this line. For more information,
  # see https://developer.apple.com/documentation/bundleresources/privacy_manifest_files
  # s.resource_bundles = {'unified_ads_privacy' => ['unified_ads/Sources/unified_ads/PrivacyInfo.xcprivacy']}
end
