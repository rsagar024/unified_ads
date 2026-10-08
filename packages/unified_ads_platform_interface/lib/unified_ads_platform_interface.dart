/// Platform interface shared by the unified_ads core and its network adapters.
///
/// Apps normally import `package:unified_ads/unified_ads.dart`, which
/// re-exports this library. Adapter packages depend on this library only.
library;

export 'src/ad_config.dart';
export 'src/ad_error.dart';
export 'src/ad_event.dart';
export 'src/ad_format.dart';
export 'src/ad_handle.dart';
export 'src/ad_network.dart';
export 'src/ad_network_adapter.dart';
export 'src/ad_result.dart';
export 'src/adapter_registry.dart';
export 'src/ads_logger.dart';
export 'src/banner_request.dart';
export 'src/banner_size.dart';
export 'src/bridged_adapter.dart';
export 'src/consent.dart';
export 'src/frequency_cap.dart';
export 'src/network_config.dart';
export 'src/platform_value.dart';
export 'src/preload_policy.dart';
export 'src/reward_item.dart';
export 'src/test_mode_support.dart';
export 'src/tracking.dart';
export 'src/unsupported_adapter.dart';
