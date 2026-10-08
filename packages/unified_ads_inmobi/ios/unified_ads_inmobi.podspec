#
# unified_ads_inmobi: InMobi adapter for unified_ads.
# The InMobi pod is declared ONLY here, so apps that do not depend on
# unified_ads_inmobi never install it (ARCHITECTURE.md section 4.2).
#
Pod::Spec.new do |s|
  s.name             = 'unified_ads_inmobi'
  s.version          = '1.0.0'
  s.summary          = 'InMobi adapter for unified_ads.'
  s.description      = <<-DESC
InMobi adapter for the unified_ads Flutter plugin: banner, interstitial and
rewarded ads.
                       DESC
  s.homepage         = 'https://github.com/OWNER/unified_ads'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'The unified_ads Authors' => 'unified_ads@example.invalid' }
  s.source           = { :path => '.' }
  s.source_files     = 'unified_ads_inmobi/Sources/unified_ads_inmobi/**/*.swift'
  s.resource_bundles = {
    'unified_ads_inmobi_privacy' => ['unified_ads_inmobi/Sources/unified_ads_inmobi/PrivacyInfo.xcprivacy']
  }
  s.dependency 'Flutter'
  s.dependency 'InMobiSDK', '11.5.0'
  s.platform = :ios, '13.0'
  s.static_framework = true

  # Flutter.framework does not contain a i386 slice.
  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.9'
end
