import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:unified_ads_platform_interface/unified_ads_platform_interface.dart';

import 'frequency.dart';
import 'init_result.dart';
import 'session.dart';
import 'tracking_channel.dart';

/// Process-wide state behind the `UnifiedAds` facade.
class AdsRuntime {
  AdsRuntime._();

  /// The singleton.
  static final AdsRuntime instance = AdsRuntime._();

  /// Clock used by new sessions. Replaceable in tests.
  @visibleForTesting
  DateTime Function() clock = DateTime.now;

  /// ATT implementation. Replaceable in tests.
  TrackingAuthorization tracking = const MethodChannelTracking();

  /// Latest consent state, applied to every adapter.
  ConsentState consent = ConsentState.unknown;

  /// Result of the most recent init.
  InitResult? lastInitResult;

  /// Events of every session; closed and recreated on every init/dispose
  /// cycle so that stale subscribers cannot receive events from a disposed
  /// session and the controllers are never leaked.
  StreamController<AdEvent> _events = StreamController.broadcast();

  /// Emits the new value whenever [adFree] changes; closed and recreated on
  /// every init/dispose cycle.
  StreamController<bool> _adFreeChanges = StreamController.broadcast();
  FrequencyStore _defaultFrequencyStore = InMemoryFrequencyStore();
  FrequencyStore? _frequencyStore;
  AdsSession? _session;
  bool _adFree = false;
  bool _blockRewarded = false;

  /// Time of the first init of this process; start of
  /// `AdPacing.initialDelay`. Not reset by re-initialization.
  DateTime? startedAt;

  /// Action counter for `AdPacing.showEveryActions`; survives
  /// re-initialization.
  final ActionCounter actions = ActionCounter();
  Completer<void>? _lock;

  /// Events of every session; survives re-initialization.
  Stream<AdEvent> get events => _events.stream;

  /// The current, non-disposed session.
  AdsSession? get session {
    final s = _session;
    return s == null || s.isDisposed ? null : s;
  }

  /// Whether ads are switched off (see `UnifiedAds.setAdFree`).
  bool get adFree => _adFree;

  /// Whether the ad-free switch also blocks rewarded formats.
  bool get blockRewarded => _blockRewarded;

  /// Emits the new value whenever [adFree] changes.
  Stream<bool> get adFreeChanges => _adFreeChanges.stream;

  /// Whether ads of [format] are currently blocked by the ad-free switch.
  bool isBlocked(AdFormat format) {
    if (!_adFree) return false;
    return !format.isRewarded || _blockRewarded;
  }

  /// Switches ads on or off for the whole app.
  Future<void> setAdFree(bool adFree, {bool blockRewarded = false}) async {
    final changed = adFree != _adFree;
    _adFree = adFree;
    _blockRewarded = blockRewarded;
    if (adFree) await session?.dropBlocked(isBlocked);
    if (changed) _adFreeChanges.add(adFree);
  }

  /// Counts one user action and persists the count.
  Future<int> recordAction() async {
    final count = ++actions.count;
    try {
      await (_frequencyStore ?? _defaultFrequencyStore).writeActionCount(count);
    } catch (e) {
      AdsLogger.current.warning('saving the action count failed', error: e);
    }
    return count;
  }

  /// Whether at least one network is ready.
  bool get isInitialized => session?.readyNetworks.isNotEmpty ?? false;

  /// Runs [action] once no other init/dispose is in progress, so concurrent
  /// calls never interleave.
  ///
  /// No future is kept between calls: a long-lived future would schedule its
  /// continuations in the zone it was created in, which deadlocks callers
  /// running in another zone (for example `testWidgets`' fake-async zone).
  ///
  /// Re-entrant calls (for example `init()` called from within an adapter's
  /// initialization callback) are rejected with a [StateError] instead of
  /// blocking, to prevent self-deadlock: the outer call holds `_lock` and
  /// won't release it until `action()` completes, but `action()` is waiting
  /// for the inner `_serialized` call to release `_lock`.
  Future<T> _serialized<T>(Future<T> Function() action) async {
    // Detect re-entrancy: if `_serialized` appears more than once in the
    // stack trace, this call is nested inside a previous `_serialized`
    // action. Awaiting another `_serialized` here would self-deadlock.
    final trace = StackTrace.current.toString();
    final first = trace.indexOf('_serialized');
    final last = trace.lastIndexOf('_serialized');
    if (first != -1 && first != last) {
      throw StateError(
        '_serialized called re-entrantly. Re-entrant init/dispose '
        'is not allowed.',
      );
    }

    // Wait for any in-progress serialized action from a concurrent caller.
    while (_lock != null) {
      await _lock!.future;
    }

    final lock = _lock = Completer<void>();
    try {
      return await action();
    } finally {
      _lock = null;
      lock.complete();
    }
  }

  /// Disposes the current session and initializes a new one.
  Future<InitResult> init(
    AdConfig config, {
    List<AdNetworkAdapter> adapters = const [],
    ConsentState? consent,
    FrequencyStore? frequencyStore,
  }) {
    return _serialized(() async {
      await _disposeSession();
      if (consent != null) this.consent = consent;
      startedAt ??= clock();
      final store = _frequencyStore = frequencyStore ?? _defaultFrequencyStore;
      try {
        await actions.restore(store);
      } catch (e) {
        AdsLogger.current.warning('reading the action count failed', error: e);
      }
      final session = AdsSession(
        config: config,
        clock: () => clock(),
        frequencyStore: store,
        eventSink: _events.add,
        startedAt: startedAt,
        actions: actions,
        isBlocked: isBlocked,
      );
      InitResult result;
      try {
        result = await session.initialize(
          explicitAdapters: adapters,
          consent: this.consent,
        );
      } catch (e, st) {
        AdsLogger.current.error('init failed', error: e, stackTrace: st);
        result = InitResult(error: AdError.fromException(e));
      }
      if (result.error != null) {
        await session.dispose();
      } else {
        _session = session;
      }
      lastInitResult = result;
      AdsLogger.current.info(
        'init: ready=${result.ready.map((n) => n.id).toList()}, '
        'failed=${result.failed.length}, skipped=${result.skipped.length}');
      for (final MapEntry(key: network, value: error)
          in result.failed.entries) {
        AdsLogger.current.warning(
          'init failed: ${error.code.name} ${maskAdIds(error.message)}'
          '${error.nativeCode == null ? '' : ' [${error.nativeCode}]'}',
          network: network,
        );
      }
      return result;
    });
  }

  /// Disposes the current session.
  Future<void> dispose() => _serialized(_disposeSession);

  Future<void> _disposeSession() async {
    final s = _session;
    _session = null;
    if (s != null) await s.dispose();
    await _events.close();
    await _adFreeChanges.close();
    _events = StreamController.broadcast();
    _adFreeChanges = StreamController.broadcast();
  }

  /// Stores [state] and forwards it to the current session's adapters.
  Future<void> updateConsent(ConsentState state) async {
    consent = state;
    await session?.applyConsent(state);
  }

  /// Restores the initial state. For tests only.
  @visibleForTesting
  Future<void> reset() async {
    await dispose();
    clock = DateTime.now;
    tracking = const MethodChannelTracking();
    consent = ConsentState.unknown;
    lastInitResult = null;
    _frequencyStore = null;
    _defaultFrequencyStore = InMemoryFrequencyStore();
    _adFree = false;
    _blockRewarded = false;
    startedAt = null;
    actions
      ..count = 0
      ..marks.clear();
  }
}
