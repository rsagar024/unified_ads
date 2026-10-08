import 'dart:async';

import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'guard.dart';
import 'session.dart';

/// A network chosen to attempt a load, with the ad-unit ID to use.
typedef WaterfallCandidate = ({AdNetwork network, String adUnitId});

/// The networks a load will try, plus why the others were excluded.
typedef WaterfallPlan = ({
  List<WaterfallCandidate> candidates,
  List<AdError> skipped,
});

/// Tries networks in waterfall order until one fills.
class WaterfallEngine {
  /// Creates an engine bound to a session.
  WaterfallEngine(this._session);

  final AdsSession _session;

  /// Computes which networks may serve [format], honouring [force].
  WaterfallPlan plan(AdFormat format, {AdNetwork? force}) {
    final config = _session.config;
    final order = force != null ? [force] : config.effectiveWaterfall;
    final candidates = <WaterfallCandidate>[];
    final skipped = <AdError>[];

    void skip(AdNetwork network, AdErrorCode code, String message) {
      skipped.add(AdError(code: code, message: message, network: network));
    }

    for (final network in order) {
      final nc = config.networks[network];
      if (nc == null) {
        skip(
          network,
          AdErrorCode.invalidConfig,
          '${network.id} is not configured',
        );
        continue;
      }
      if (!nc.enabled) {
        skip(network, AdErrorCode.networkDisabled, '${network.id} is disabled');
        continue;
      }
      final adapter = _session.adapterFor(network);
      if (adapter == null) {
        skip(
          network,
          AdErrorCode.notInitialized,
          '${network.id} is not initialized (see UnifiedAds.lastInitResult)',
        );
        continue;
      }
      final supported = guardSync<Set<AdFormat>>(
        network,
        'supportedFormats',
        const {},
        () => adapter.supportedFormats,
      );
      if (!supported.contains(format)) {
        skip(
          network,
          AdErrorCode.unsupportedFormat,
          '${network.id} does not support ${format.id}',
        );
        continue;
      }
      if (!nc.isFormatEnabled(format)) {
        skip(
          network,
          AdErrorCode.formatDisabled,
          '${format.id} is disabled for ${network.id}',
        );
        continue;
      }
      final adUnitId = nc.adUnitIdFor(format) ?? '';
      if (adUnitId.isEmpty && adapter.requiresAdUnitId) {
        skip(
          network,
          AdErrorCode.invalidConfig,
          'networks.${network.id}.${format.id}AdUnitId is not set',
        );
        continue;
      }
      candidates.add((network: network, adUnitId: adUnitId));
    }
    return (candidates: candidates, skipped: skipped);
  }

  /// Loads a full-screen ad of [format] from the first network that fills.
  ///
  /// With a single attempted (or excluded) network its error is returned as
  /// is; otherwise an [AdErrorCode.noFill] error lists every attempt.
  Future<AdResult<AdHandle>> load(AdFormat format, {AdNetwork? force}) async {
    final (:candidates, :skipped) = plan(format, force: force);
    final logger = AdsLogger.current;
    for (final s in skipped) {
      logger.debug('waterfall skip: ${s.message}', network: s.network);
    }
    if (candidates.isEmpty) {
      if (skipped.length == 1) return AdFailure(skipped.single);
      return AdFailure(
        AdError(
          code: AdErrorCode.noFill,
          message: 'No initialized network can serve ${format.id}',
          attempts: skipped,
        ),
      );
    }

    final attempts = <AdError>[];
    for (final c in candidates) {
      logger.debug(
        'loading ${format.id} (${maskId(c.adUnitId)})',
        network: c.network,
      );
      final result = await _attempt(c.network, format, c.adUnitId);
      switch (result) {
        case AdSuccess():
          logger.info('loaded ${format.id}', network: c.network);
          return result;
        case AdFailure(:final error):
          logger.info(
            'failed ${format.id}: ${error.message}',
            network: c.network,
          );
          attempts.add(error);
      }
    }
    if (attempts.length == 1) return AdFailure(attempts.single);
    return AdFailure(
      AdError(
        code: AdErrorCode.noFill,
        message: 'All ${attempts.length} networks failed to load ${format.id}',
        attempts: attempts,
      ),
    );
  }

  Future<AdResult<AdHandle>> _attempt(
    AdNetwork network,
    AdFormat format,
    String adUnitId,
  ) async {
    final adapter = _session.adapterFor(network)!;
    final timeout = _session.config.loadTimeout;
    final future = guardCall(
      network,
      'load',
      () => adapter.load(format, adUnitId),
    );
    try {
      return await future.timeout(timeout);
    } on TimeoutException {
      // The SDK may still fill later; release that ad since nobody owns it.
      unawaited(
        future.then((late) async {
          if (late case AdSuccess(:final value)) await _session.destroy(value);
        }),
      );
      return AdFailure(
        AdError(
          code: AdErrorCode.timeout,
          message:
              '${format.id} load timed out after ${timeout.inMilliseconds} ms',
          network: network,
        ),
      );
    }
  }
}
