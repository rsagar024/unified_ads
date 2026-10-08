#
# unified_ads_admob: AdMob adapter for unified_ads.
# The Google Mobile Ads + UMP pods are declared ONLY here, so apps that do not
# depend on unified_ads_admob never install them (ARCHITECTURE.md §4.2).
#
Pod::Spec.new do |s|
  s.name             = 'unified_ads_admob'
  s.version          = '1.0.0'
  s.summary          = 'AdMob (Google Mobile Ads) adapter for unified_ads.'
  s.description      = <<-DESC
AdMob adapter for the unified_ads Flutter plugin: banner, interstitial and
rewarded ads plus a Google UMP consent provider.
                       DESC
  s.homepage         = 'https://github.com/OWNER/unified_ads'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'The unified_ads Authors' => 'unified_ads@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'unified_ads_admob/Sources/unified_ads_admob/**/*.swift'
  s.resource_bundles = {
    'unified_ads_admob_privacy' => ['unified_ads_admob/Sources/unified_ads_admob/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.dependency 'Google-Mobile-Ads-SDK', '13.11.0'
  s.dependency 'GoogleUserMessagingPlatform', '3.1.0'
  s.platform = :ios, '13.0'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
