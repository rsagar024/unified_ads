import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

/// Result of validating an [AdConfig].
class ValidationReport {
  /// Creates a report.
  const ValidationReport({this.global = const [], this.networks = const {}});

  /// Errors that make the whole configuration unusable.
  final List<AdError> global;

  /// Errors that disable a single network.
  final Map<AdNetwork, AdError> networks;

  /// Whether the configuration can be used (possibly without some networks).
  bool get isUsable => global.isEmpty;
}

/// Networks whose `NetworkConfig.appId` is mandatory.
const _appIdRequired = {
  AdNetwork.admob,
  AdNetwork.unity,
  AdNetwork.applovin,
  AdNetwork.ironsource,
  AdNetwork.startapp,
  AdNetwork.inmobi,
};

/// Validates [config] (see ARCHITECTURE.md §6).
ValidationReport validateConfig(AdConfig config) {
  final global = <AdError>[];
  final perNetwork = <AdNetwork, AdError>{};

  AdError invalid(String message, {AdNetwork? network}) => AdError(
    code: AdErrorCode.invalidConfig,
    message: message,
    network: network,
  );

  final seen = <AdNetwork>{};
  for (var i = 0; i < config.waterfall.length; i++) {
    final network = config.waterfall[i];
    if (!seen.add(network)) {
      global.add(invalid('waterfall[$i]: ${network.id} is listed twice'));
    }
    if (!config.networks.containsKey(network)) {
      global.add(
        invalid('waterfall[$i]: ${network.id} has no entry in networks'),
      );
    }
  }
  if (config.loadTimeout <= Duration.zero) {
    global.add(invalid('loadTimeout must be positive'));
  }
  if (config.initTimeout <= Duration.zero) {
    global.add(invalid('initTimeout must be positive'));
  }
  if (config.cacheTtl <= Duration.zero) {
    global.add(invalid('cacheTtl must be positive'));
  }
  config.frequencyCaps.forEach((format, cap) {
    if (!format.isFullScreen) {
      global.add(
        invalid('frequencyCaps.${format.id}: only full-screen formats'),
      );
    }
    if (cap.maxShows <= 0 || cap.per <= Duration.zero) {
      global.add(
        invalid(
          'frequencyCaps.${format.id}: maxShows and per must be positive',
        ),
      );
    }
  });

  config.networks.forEach((network, nc) {
    if (!nc.enabled) return;
    final path = 'networks.${network.id}';
    if (_appIdRequired.contains(network) && (nc.appId?.trim() ?? '').isEmpty) {
      perNetwork[network] = invalid(
        '$path.appId is required',
        network: network,
      );
      return;
    }
    if (network == AdNetwork.inmobi) {
      for (final format in AdFormat.values) {
        final id = nc.adUnitIdFor(format);
        if (id != null && id.isNotEmpty && int.tryParse(id) == null) {
          perNetwork[network] = invalid(
            '$path.${format.id}AdUnitId must be a numeric InMobi placement ID',
            network: network,
          );
          return;
        }
      }
    }
  });

  return ValidationReport(global: global, networks: perNetwork);
}
