import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unified_ads/unified_ads.dart';

import 'ads_controller.dart';
import 'event_log.dart';

/// Banner sizes offered by the size selector.
const Map<String, BannerSize> bannerSizes = {
  'Adaptive': BannerSize.adaptiveInline(),
  'Standard 320×50': BannerSize.standard,
  'Large 320×100': BannerSize.largeBanner,
  'Medium rectangle 300×250': BannerSize.mediumRectangle,
};

/// The demo screen: init status per network, a waterfall card, and one card
/// per network with buttons that load and show its banner, interstitial and
/// rewarded ads right here.
class AdsScreen extends StatefulWidget {
  /// Creates the screen.
  const AdsScreen({required this.controller, required this.log, super.key});

  /// Init state and configuration.
  final AdsController controller;

  /// Event console.
  final EventLog log;

  @override
  State<AdsScreen> createState() => _AdsScreenState();
}

class _AdsScreenState extends State<AdsScreen> {
  String _size = bannerSizes.keys.first;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final controller = widget.controller;
        final order = [
          ...?controller.config?.effectiveWaterfall,
          ...AdNetwork.values.where(
            (n) =>
                !(controller.config?.effectiveWaterfall.contains(n) ?? false),
          ),
        ];
        final size = bannerSizes[_size]!;
        return ListView(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
          children: [
            _StatusHeader(
              controller: controller,
              order: order,
              size: _size,
              onSizeChanged: (s) => setState(() => _size = s),
            ),
            const SizedBox(height: 8),
            AdTestCard(
              key: ValueKey('waterfall-${controller.generation}'),
              network: null,
              status: null,
              bannerSize: size,
              log: widget.log,
            ),
            for (final network in order)
              AdTestCard(
                key: ValueKey('${network.id}-${controller.generation}'),
                network: network,
                status: controller.statusOf(network),
                bannerSize: size,
                log: widget.log,
              ),
          ],
        );
      },
    );
  }
}

class _StatusHeader extends StatelessWidget {
  const _StatusHeader({
    required this.controller,
    required this.order,
    required this.size,
    required this.onSizeChanged,
  });

  final AdsController controller;
  final List<AdNetwork> order;
  final String size;
  final ValueChanged<String> onSizeChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    controller.busy
                        ? 'Initializing…'
                        : UnifiedAds.isInitialized
                        ? 'Initialized: ${UnifiedAds.readyNetworks.length} '
                              'network(s) ready'
                        : 'Not initialized',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                if (controller.busy)
                  const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  TextButton.icon(
                    onPressed: controller.config == null
                        ? null
                        : controller.reinitialize,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Re-initialize'),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final network in order)
                  _NetworkChip(
                    network: network,
                    status: controller.statusOf(network),
                    scheme: scheme,
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                const Text('Banner size: '),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: size,
                    items: [
                      for (final name in bannerSizes.keys)
                        DropdownMenuItem(value: name, child: Text(name)),
                    ],
                    onChanged: (v) => v == null ? null : onSizeChanged(v),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _NetworkChip extends StatelessWidget {
  const _NetworkChip({
    required this.network,
    required this.status,
    required this.scheme,
  });

  final AdNetwork network;
  final NetworkStatus status;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (status.state) {
      NetworkState.ready => (Icons.check_circle, Colors.green),
      NetworkState.failed => (Icons.error, scheme.error),
      NetworkState.skipped => (Icons.remove_circle_outline, Colors.grey),
      NetworkState.pending => (Icons.hourglass_empty, Colors.orange),
    };
    return Chip(
      visualDensity: VisualDensity.compact,
      avatar: Icon(icon, color: color, size: 18),
      label: Text(network.id),
    );
  }
}

/// A card that tests one network ([network] set: the network is forced) or the
/// whole waterfall ([network] null).
class AdTestCard extends StatefulWidget {
  /// Creates a card.
  const AdTestCard({
    required this.network,
    required this.status,
    required this.bannerSize,
    required this.log,
    super.key,
  });

  /// The forced network, or null for the waterfall.
  final AdNetwork? network;

  /// The network's init status (null for the waterfall card).
  final NetworkStatus? status;

  /// Size used for banners.
  final BannerSize bannerSize;

  /// Event console.
  final EventLog log;

  @override
  State<AdTestCard> createState() => _AdTestCardState();
}

class _AdTestCardState extends State<AdTestCard> {
  /// Full-screen formats, in button order.
  static const _fullScreenFormats = [
    AdFormat.interstitial,
    AdFormat.rewarded,
    AdFormat.rewardedInterstitial,
    AdFormat.appOpen,
  ];

  BannerAd? _banner;
  final Map<AdFormat, FullScreenAd<dynamic>> _ads = {};
  final Map<AdFormat, String> _status = {};
  final Set<AdFormat> _busy = {};

  AdNetwork? get _network => widget.network;

  String get _label => _network?.displayName ?? 'Waterfall (auto)';

  /// Formats with Load/Show buttons: every full-screen format for the
  /// waterfall card, the adapter's `supportedFormats` for a network card.
  List<AdFormat> get _formats {
    final network = _network;
    final supported = network == null
        ? null
        : AdapterRegistry.instance.adapterFor(network)?.supportedFormats;
    return [
      for (final format in _fullScreenFormats)
        if (supported == null || supported.contains(format)) format,
    ];
  }

  static String _name(AdFormat format) => switch (format) {
    AdFormat.rewardedInterstitial => 'rewarded interstitial',
    AdFormat.appOpen => 'app open',
    _ => format.id,
  };

  bool get _usable {
    final status = widget.status;
    return status == null || status.state == NetworkState.ready;
  }

  @override
  void dispose() {
    _banner?.dispose();
    for (final ad in _ads.values) {
      unawaited(ad.dispose());
    }
    super.dispose();
  }

  void _set(AdFormat format, String text) {
    if (mounted) setState(() => _status[format] = text);
  }

  String _served(AdNetwork? network) =>
      network == null ? '' : ' (served by ${network.id})';

  void _toggleBanner() {
    final current = _banner;
    if (current != null) {
      current.dispose();
      setState(() {
        _banner = null;
        _status.remove(AdFormat.banner);
      });
      return;
    }
    setState(() {
      _status[AdFormat.banner] = 'loading…';
      _banner = BannerAd(
        size: widget.bannerSize,
        forceNetwork: _network,
        onLoaded: (ad) {
          _set(AdFormat.banner, 'showing${_served(ad.servedBy)}');
          widget.log.add(
            'banner',
            'loaded${_served(ad.servedBy)}',
            network: ad.servedBy,
            format: AdFormat.banner,
          );
        },
        onFailedToLoad: (ad, error) {
          _set(AdFormat.banner, 'failed: ${_short(error)}');
          widget.log.addError('banner', error, format: AdFormat.banner);
        },
      );
    });
  }

  Future<void> _load(AdFormat format) async {
    setState(() {
      _busy.add(format);
      _status[format] = 'loading…';
    });
    final ad = _ads[format] ??= _create(format);
    final result = await ad.load();
    if (!mounted) return;
    setState(() => _busy.remove(format));
    switch (result.errorOrNull) {
      case final error?:
        _set(format, 'load failed: ${_short(error)}');
        widget.log.addError('load', error, format: format);
      case null:
        _set(format, 'ready${_served(ad.servedBy)}: tap Show');
        widget.log.add(
          'load',
          'ready${_served(ad.servedBy)}',
          network: ad.servedBy,
          format: format,
        );
    }
  }

  FullScreenAd<dynamic> _create(AdFormat format) => switch (format) {
    AdFormat.rewarded => RewardedAd(
      forceNetwork: _network,
      onEarnedReward: (ad, reward) => _onReward(format, ad.servedBy, reward),
      onClosed: (ad) => _onClosed(format, ad.servedBy),
      onFailedToShow: (ad, error) => _onShowFailed(format, error),
    ),
    AdFormat.rewardedInterstitial => RewardedInterstitialAd(
      forceNetwork: _network,
      onEarnedReward: (ad, reward) => _onReward(format, ad.servedBy, reward),
      onClosed: (ad) => _onClosed(format, ad.servedBy),
      onFailedToShow: (ad, error) => _onShowFailed(format, error),
    ),
    AdFormat.appOpen => AppOpenAd(
      forceNetwork: _network,
      onClosed: (ad) => _onClosed(format, ad.servedBy),
      onFailedToShow: (ad, error) => _onShowFailed(format, error),
    ),
    _ => InterstitialAd(
      forceNetwork: _network,
      onClosed: (ad) => _onClosed(format, ad.servedBy),
      onFailedToShow: (ad, error) => _onShowFailed(format, error),
    ),
  };

  void _onReward(AdFormat format, AdNetwork? network, RewardItem reward) {
    _set(format, 'reward earned: ${reward.amount} ${reward.type}');
    widget.log.add(
      'reward',
      '${reward.amount} ${reward.type}${_served(network)}',
      network: network,
      format: format,
    );
  }

  Future<void> _show(AdFormat format) async {
    final ad = _ads[format];
    if (ad == null || !ad.isReady) {
      _set(format, 'not loaded: tap Load first');
      return;
    }
    final result = await ad.show();
    if (result.errorOrNull case final error?) {
      _onShowFailed(format, error);
    } else {
      _set(format, 'showing${_served(ad.servedBy)}');
    }
  }

  void _onClosed(AdFormat format, AdNetwork? network) {
    if (_status[format]?.startsWith('reward') ?? false) return;
    _set(format, 'closed${_served(network)}');
  }

  void _onShowFailed(AdFormat format, AdError error) {
    _set(format, 'show failed: ${_short(error)}');
    widget.log.addError('show', error, format: format);
  }

  static String _short(AdError error) {
    final native = error.nativeCode == null ? '' : ' [${error.nativeCode}]';
    return '${error.code.name}$native';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = widget.status;
    final enabled = _usable;
    final banner = _banner;
    return Card(
      key: ValueKey('card-${_network?.id ?? 'waterfall'}'),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_label, style: theme.textTheme.titleMedium),
            if (!enabled && status != null)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  switch (status) {
                    (state: NetworkState.pending, error: _) =>
                      'Waiting for init…',
                    (state: _, error: final e?) =>
                      '${e.code.name}: ${e.message}',
                    _ => 'Disabled: enable it in Settings.',
                  },
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: status.state == NetworkState.failed
                        ? theme.colorScheme.error
                        : theme.hintColor,
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonal(
                  onPressed: enabled ? _toggleBanner : null,
                  child: Text(banner == null ? 'Banner' : 'Hide banner'),
                ),
                for (final format in _formats) ...[
                  FilledButton(
                    onPressed: enabled && !_busy.contains(format)
                        ? () => _load(format)
                        : null,
                    child: Text('Load ${_name(format)}'),
                  ),
                  OutlinedButton(
                    onPressed: enabled ? () => _show(format) : null,
                    child: Text('Show ${_name(format)}'),
                  ),
                ],
              ],
            ),
            for (final format in AdFormat.values)
              if (_status[format] case final text?)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '${format.id}: $text',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: text.contains('failed')
                          ? theme.colorScheme.error
                          : null,
                    ),
                  ),
                ),
            if (banner != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: UnifiedBannerWidget(
                  ad: banner,
                  placeholder: const Center(child: Text('Loading banner…')),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
