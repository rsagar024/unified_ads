import 'dart:async';

import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'ad_cache.dart';
import 'config_validator.dart';
import 'frequency.dart';
import 'guard.dart';
import 'init_result.dart';
import 'waterfall.dart';

/// One initialized configuration: its adapters, cache, frequency limiter and
/// event fan-in. Replaced on every `UnifiedAds.init`.
class AdsSession {
  /// Creates a session; call [initialize] before use.
  AdsSession({
    required this.config,
    required this.clock,
    required FrequencyStore frequencyStore,
    required this.eventSink,
  }) : cache = AdCache(ttl: config.cacheTtl, now: clock),
       frequency = FrequencyLimiter(
         caps: config.frequencyCaps,
         store: frequencyStore,
         now: clock,
       );

  /// The configuration this session was created with.
  final AdConfig config;

  /// Clock used for caching and frequency capping.
  final DateTime Function() clock;

  /// Preloaded full-screen ads.
  final AdCache cache;

  /// Frequency capping.
  final FrequencyLimiter frequency;

  /// Waterfall loader.
  late final WaterfallEngine waterfall = WaterfallEngine(this);

  /// Whether a full-screen ad from this session is currently on screen.
  bool fullScreenShowing = false;

  /// Receives every event of this session (the runtime-wide stream).
  final void Function(AdEvent event) eventSink;

  final Map<AdNetwork, AdNetworkAdapter> _ready = {};
  final Map<AdNetwork, AdNetworkAdapter> _attached = {};
  final List<StreamSubscription<AdEvent>> _subscriptions = [];
  final StreamController<AdEvent> _events = StreamController.broadcast();
  final Map<AdFormat, Future<AdResult<void>>> _refills = {};
  int _adCounter = 0;
  bool _disposed = false;

  /// Whether [dispose] has been called.
  bool get isDisposed => _disposed;

  /// Networks that initialized successfully.
  Set<AdNetwork> get readyNetworks => Set.unmodifiable(_ready.keys);

  /// Events of every adapter in this session.
  Stream<AdEvent> get events => _events.stream;

  /// The ready adapter for [network], or `null`.
  AdNetworkAdapter? adapterFor(AdNetwork network) => _ready[network];

  /// A session-unique id for an ad created on the Dart side (banners).
  String nextAdId(AdNetwork network, AdFormat format) =>
      '${network.id}-${format.id}-${++_adCounter}';

  /// Validates the config, resolves adapters, applies guards and initializes
  /// every remaining network in parallel.
  Future<InitResult> initialize({
    required List<AdNetworkAdapter> explicitAdapters,
    required ConsentState consent,
  }) async {
    final logger = AdsLogger.current;
    final report = validateConfig(config);
    if (!report.isUsable) {
      return InitResult(
        error: AdError(
          code: AdErrorCode.invalidConfig,
          message:
              'Invalid AdConfig: ${report.global.map((e) => e.message).join('; ')}',
          attempts: report.global,
        ),
      );
    }

    final skipped = <AdNetwork, AdError>{...report.networks};
    final explicit = {for (final a in explicitAdapters) a.network: a};
    final candidates = <AdNetwork, AdNetworkAdapter>{};
    for (final MapEntry(key: network, value: nc) in config.networks.entries) {
      if (skipped.containsKey(network)) continue;
      if (!nc.enabled) {
        skipped[network] = AdError(
          code: AdErrorCode.networkDisabled,
          message: '${network.id} is disabled in config',
          network: network,
        );
        continue;
      }
      final adapter =
          explicit[network] ?? AdapterRegistry.instance.adapterFor(network);
      if (adapter == null) {
        skipped[network] = AdError(
          code: AdErrorCode.adapterMissing,
          message:
              'No adapter for ${network.id}. Add the unified_ads_${network.id} '
              'package to pubspec.yaml.',
          network: network,
        );
        continue;
      }
      candidates[network] = adapter;
    }

    if (candidates.containsKey(AdNetwork.unity) &&
        candidates.containsKey(AdNetwork.ironsource)) {
      candidates.remove(AdNetwork.unity);
      skipped[AdNetwork.unity] = const AdError(
        code: AdErrorCode.configConflict,
        message:
            'Unity Ads cannot run alongside LevelPlay in one app (the Unity SDK '
            'initializes once per process). Unity was skipped; get Unity demand '
            'through LevelPlay instead.',
        network: AdNetwork.unity,
      );
    }
    if (consent.coppa && candidates.containsKey(AdNetwork.applovin)) {
      candidates.remove(AdNetwork.applovin);
      skipped[AdNetwork.applovin] = _maxCoppaError;
    }

    final failed = <AdNetwork, AdError>{};
    await Future.wait(
      candidates.entries.map((entry) async {
        final network = entry.key;
        final adapter = entry.value;
        _attached[network] = adapter;
        final events = guardSync<Stream<AdEvent>>(
          network,
          'events',
          const Stream.empty(),
          () => adapter.events,
        );
        _subscriptions.add(
          events.listen(
            _onAdapterEvent,
            onError: (Object e, StackTrace st) => logger.error(
              'event stream error',
              network: network,
              error: e,
              stackTrace: st,
            ),
          ),
        );
        await guardVoid(
          network,
          'applyConsent',
          () => adapter.applyConsent(consent),
        );
        final testMode = config.isTestMode(network);
        final result =
            await guardCall(
              network,
              'initialize',
              () => adapter.initialize(
                config.networks[network]!,
                testMode: testMode,
              ),
            ).timeout(
              config.initTimeout,
              onTimeout: () => AdFailure(
                AdError(
                  code: AdErrorCode.initializationFailed,
                  message:
                      'initialization timed out after ${config.initTimeout.inSeconds} s',
                  network: network,
                ),
              ),
            );
        switch (result) {
          case AdSuccess():
            _ready[network] = adapter;
            if (testMode && !adapter.testModeSupport.canForceTestAds) {
              logger.warning(
                'testMode is on, but ${network.displayName} can only serve test '
                'ads when configured in its dashboard '
                '(${adapter.testModeSupport.name}).',
                network: network,
              );
            }
          case AdFailure(:final error):
            failed[network] = error;
        }
      }),
    );

    if (config.preload.onInit) {
      for (final format in config.preload.formats) {
        unawaited(refill(format));
      }
    }
    return InitResult(
      ready: readyNetworks,
      failed: Map.unmodifiable(failed),
      skipped: Map.unmodifiable(skipped),
    );
  }

  static const _maxCoppaError = AdError(
    code: AdErrorCode.configConflict,
    message:
        'AppLovin MAX removed COPPA support (SDK 13.0) and must not be '
        'initialized for child-directed users.',
    network: AdNetwork.applovin,
  );

  void _onAdapterEvent(AdEvent event) {
    if (_disposed) return;
    AdsLogger.current.verbose('event $event', network: event.network);
    _events.add(event);
    eventSink(event);
  }

  /// Whether [handle] can still be shown.
  bool isHandleReady(AdHandle handle) {
    final adapter = _ready[handle.network];
    if (adapter == null) return false;
    return guardSync(
      handle.network,
      'isReady',
      false,
      () => adapter.isReady(handle),
    );
  }

  /// Shows [handle] through its adapter.
  Future<AdResult<void>> show(AdHandle handle) {
    final adapter = _ready[handle.network];
    if (adapter == null) {
      return Future.value(
        AdFailure(
          AdError(
            code: AdErrorCode.notReady,
            message: '${handle.network.id} is no longer initialized',
            network: handle.network,
          ),
        ),
      );
    }
    return guardCall(handle.network, 'show', () => adapter.show(handle));
  }

  /// Releases [handle] through its adapter.
  Future<void> destroy(AdHandle handle) async {
    final adapter = _attached[handle.network];
    if (adapter == null) return;
    await guardVoid(handle.network, 'destroy', () => adapter.destroy(handle));
  }

  /// Returns a ready ad of [format]: the cached one when possible (and
  /// matching [force]), otherwise a fresh waterfall load.
  Future<AdResult<AdHandle>> acquire(
    AdFormat format, {
    AdNetwork? force,
  }) async {
    final fromCache = _takeCached(format, force);
    if (fromCache != null) return AdSuccess(fromCache);
    final inFlight = _refills[format];
    if (inFlight != null) {
      await inFlight;
      final refilled = _takeCached(format, force);
      if (refilled != null) return AdSuccess(refilled);
    }
    return waterfall.load(format, force: force);
  }

  AdHandle? _takeCached(AdFormat format, AdNetwork? force) {
    final peeked = cache.peek(format);
    if (peeked == null) {
      // Evict (and release) an expired entry, if there is one.
      cache.take(format, expired: (h) => unawaited(destroy(h)));
      return null;
    }
    if (force != null && peeked.network != force) return null;
    final handle = cache.take(format, expired: (h) => unawaited(destroy(h)));
    if (handle == null) return null;
    if (isHandleReady(handle)) return handle;
    unawaited(destroy(handle));
    return null;
  }

  /// Loads an ad of [format] into the cache unless one is cached or loading.
  Future<AdResult<void>> refill(AdFormat format) {
    if (_disposed) {
      return Future.value(
        const AdFailure(
          AdError(
            code: AdErrorCode.notInitialized,
            message: 'session disposed',
          ),
        ),
      );
    }
    if (cache.has(format)) return Future.value(const AdSuccess(null));
    // The callback must not return the removed future: whenComplete would
    // then wait for the very future it belongs to and never complete.
    return _refills[format] ??= _doRefill(format).whenComplete(() {
      _refills.remove(format)?.ignore();
    });
  }

  /// Calls [refill] when the preload policy covers [format].
  Future<void> refillIfEnabled(AdFormat format) async {
    if (config.preload.isEnabledFor(format)) await refill(format);
  }

  Future<AdResult<void>> _doRefill(AdFormat format) async {
    final result = await waterfall.load(format);
    switch (result) {
      case AdSuccess(:final value):
        if (_disposed) {
          await destroy(value);
          return const AdSuccess(null);
        }
        final replaced = cache.put(value);
        if (replaced != null) await destroy(replaced);
        return const AdSuccess(null);
      case AdFailure(:final error):
        AdsLogger.current.debug(
          'preload of ${format.id} failed: ${error.message}',
        );
        return AdFailure(error);
    }
  }

  /// Forwards [state] to every adapter of this session.
  Future<void> applyConsent(ConsentState state) async {
    if (state.coppa && _ready.containsKey(AdNetwork.applovin)) {
      _ready.remove(AdNetwork.applovin);
      AdsLogger.current.warning(
        _maxCoppaError.message,
        network: AdNetwork.applovin,
      );
    }
    await Future.wait(
      _attached.entries.map(
        (e) =>
            guardVoid(e.key, 'applyConsent', () => e.value.applyConsent(state)),
      ),
    );
  }

  /// Destroys cached ads, disposes every adapter and stops event delivery.
  Future<void> dispose() async {
    if (_disposed) return;
    for (final handle in cache.clear()) {
      await destroy(handle);
    }
    _disposed = true;
    for (final s in _subscriptions) {
      await s.cancel();
    }
    _subscriptions.clear();
    await Future.wait(
      _attached.entries.map(
        (e) => guardVoid(e.key, 'dispose', () => e.value.dispose()),
      ),
    );
    _ready.clear();
    _attached.clear();
    await _events.close();
  }
}
