#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint unified_ads.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'unified_ads'
  s.version          = '1.0.1'
  s.summary          = 'Core of the unified_ads Flutter plugin.'
  s.description      = <<-DESC
Core of the unified_ads Flutter plugin (no ad SDKs; ATT helper only).
                       DESC
  s.homepage         = 'https://github.com/rsagar024/unified_ads'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'The unified_ads Authors' => 'unified_ads@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files = 'unified_ads/Sources/unified_ads/**/*.swift'
  s.dependency 'Flutter'
  # ATT (iOS 14+) is weak-linked so the plugin still loads on iOS 13.
  s.weak_frameworks = 'AppTrackingTransparency'
  s.platform = :ios, '13.0'

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'

  # Privacy manifest: the core collects nothing and uses no required-reason
  # API (ATT helper only). Bundled like every adapter's (doc/ios_setup.md).
  s.resource_bundles = {'unified_ads_privacy' => ['unified_ads/Sources/unified_ads/PrivacyInfo.xcprivacy']}
end
