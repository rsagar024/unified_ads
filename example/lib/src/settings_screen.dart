import 'package:flutter/material.dart';
import 'package:unified_ads/unified_ads.dart';

import 'ads_controller.dart';

/// Edits the configuration: which networks are enabled, their App / ad-unit
/// IDs, test mode, and the waterfall order. "Save & re-initialize" persists it
/// and re-runs `UnifiedAds.init`.
class SettingsScreen extends StatefulWidget {
  /// Creates the screen.
  const SettingsScreen({required this.controller, super.key});

  /// Owns the configuration.
  final AdsController controller;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _testMode = true;
  List<AdNetwork> _waterfall = [];
  final Map<AdNetwork, _NetworkForm> _forms = {};
  AdConfig? _source;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_sync);
    _sync();
  }

  @override
  void dispose() {
    widget.controller.removeListener(_sync);
    for (final form in _forms.values) {
      form.dispose();
    }
    super.dispose();
  }

  /// Reloads the form when the controller's configuration object changes
  /// (first load, reset).
  void _sync() {
    final config = widget.controller.config;
    if (config == null || identical(config, _source)) return;
    _source = config;
    for (final form in _forms.values) {
      form.dispose();
    }
    _forms
      ..clear()
      ..addAll({
        for (final n in AdNetwork.values)
          n: _NetworkForm(
            config.networks[n] ?? const NetworkConfig(enabled: false),
          ),
      });
    final order = config.effectiveWaterfall;
    setState(() {
      _testMode = config.testMode;
      _waterfall = [
        ...order,
        ...AdNetwork.values.where((n) => !order.contains(n)),
      ];
    });
  }

  AdConfig _build() {
    final base = widget.controller.config ?? const AdConfig();
    return base.copyWith(
      testMode: _testMode,
      waterfall: _waterfall,
      networks: {for (final n in _waterfall) n: _forms[n]!.toConfig()},
    );
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    final config = _build();
    _source = config;
    await widget.controller.apply(config);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Saved. Ads re-initialized.')),
      );
    }
  }

  Future<void> _reset() async {
    await widget.controller.resetToTestIds();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restored the public test IDs.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_forms.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 24),
      children: [
        Card(
          child: SwitchListTile(
            title: const Text('Test mode (all networks)'),
            subtitle: const Text(
              'Forces test ads where the network supports it. '
              'A per-network setting overrides it.',
            ),
            value: _testMode,
            onChanged: (v) => setState(() => _testMode = v),
          ),
        ),
        const SizedBox(height: 8),
        Text('Waterfall order', style: theme.textTheme.titleMedium),
        Text(
          'Drag to reorder. "Waterfall (auto)" ads try enabled networks in '
          'this order.',
          style: theme.textTheme.bodySmall,
        ),
        Card(
          child: ReorderableListView(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            onReorderItem: (from, to) => setState(() {
              final item = _waterfall.removeAt(from);
              _waterfall.insert(to, item);
            }),
            children: [
              for (final (i, n) in _waterfall.indexed)
                ListTile(
                  key: ValueKey(n),
                  dense: true,
                  leading: Text('${i + 1}'),
                  title: Text(n.displayName),
                  subtitle: _forms[n]!.enabled ? null : const Text('disabled'),
                  trailing: ReorderableDragStartListener(
                    index: i,
                    child: const Icon(Icons.drag_handle),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Text('Networks', style: theme.textTheme.titleMedium),
        for (final n in _waterfall)
          _NetworkTile(
            key: ValueKey('settings-${n.id}'),
            network: n,
            form: _forms[n]!,
            onChanged: () => setState(() {}),
          ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: widget.controller.busy ? null : _save,
          icon: const Icon(Icons.save),
          label: const Text('Save & re-initialize'),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: widget.controller.busy ? null : _reset,
          icon: const Icon(Icons.restore),
          label: const Text('Reset to public test IDs'),
        ),
        const SizedBox(height: 8),
        Text(
          'Some SDKs read their App ID only once per process (and AdMob reads '
          'it from AndroidManifest / Info.plist). After changing an App ID, '
          'restart the app if the network keeps the old one.',
          style: theme.textTheme.bodySmall,
        ),
      ],
    );
  }
}

/// Editable fields for one network.
class _NetworkForm {
  _NetworkForm(NetworkConfig config)
    : enabled = config.enabled,
      testMode = config.testMode,
      _extras = config.extras,
      _enabledFormats = config.enabledFormats,
      appId = TextEditingController(text: config.appId ?? ''),
      banner = TextEditingController(text: config.bannerAdUnitId ?? ''),
      interstitial = TextEditingController(
        text: config.interstitialAdUnitId ?? '',
      ),
      rewarded = TextEditingController(text: config.rewardedAdUnitId ?? ''),
      rewardedInterstitial = TextEditingController(
        text: config.rewardedInterstitialAdUnitId ?? '',
      ),
      appOpen = TextEditingController(text: config.appOpenAdUnitId ?? ''),
      testDevices = TextEditingController(
        text: config.testDeviceIds.join(', '),
      );

  bool enabled;
  bool? testMode;
  final Map<String, Object?> _extras;
  final Set<AdFormat>? _enabledFormats;
  final TextEditingController appId;
  final TextEditingController banner;
  final TextEditingController interstitial;
  final TextEditingController rewarded;
  final TextEditingController rewardedInterstitial;
  final TextEditingController appOpen;
  final TextEditingController testDevices;

  static String? _value(TextEditingController c) {
    final text = c.text.trim();
    return text.isEmpty ? null : text;
  }

  NetworkConfig toConfig() => NetworkConfig(
    enabled: enabled,
    appId: _value(appId),
    bannerAdUnitId: _value(banner),
    interstitialAdUnitId: _value(interstitial),
    rewardedAdUnitId: _value(rewarded),
    rewardedInterstitialAdUnitId: _value(rewardedInterstitial),
    appOpenAdUnitId: _value(appOpen),
    testMode: testMode,
    enabledFormats: _enabledFormats,
    testDeviceIds: [
      for (final id in testDevices.text.split(','))
        if (id.trim().isNotEmpty) id.trim(),
    ],
    extras: _extras,
  );

  void dispose() {
    appId.dispose();
    banner.dispose();
    interstitial.dispose();
    rewarded.dispose();
    rewardedInterstitial.dispose();
    appOpen.dispose();
    testDevices.dispose();
  }
}

class _NetworkTile extends StatelessWidget {
  const _NetworkTile({
    required this.network,
    required this.form,
    required this.onChanged,
    super.key,
  });

  final AdNetwork network;
  final _NetworkForm form;
  final VoidCallback onChanged;

  String get _appIdLabel => switch (network) {
    AdNetwork.admob => 'App ID (must match AndroidManifest / Info.plist)',
    AdNetwork.unity => 'Game ID',
    AdNetwork.applovin => 'SDK key',
    AdNetwork.ironsource => 'App key',
    AdNetwork.inmobi => 'Account ID',
    AdNetwork.startapp => 'App ID',
    AdNetwork.facebook => 'App ID (not needed)',
  };

  String get _unitLabel => switch (network) {
    AdNetwork.unity || AdNetwork.facebook || AdNetwork.inmobi => 'placement ID',
    AdNetwork.startapp => 'ad tag (optional)',
    _ => 'ad unit ID',
  };

  @override
  Widget build(BuildContext context) {
    Widget field(TextEditingController c, String label) => Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: TextField(
        controller: c,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      ),
    );

    return Card(
      child: ExpansionTile(
        leading: Checkbox(
          value: form.enabled,
          onChanged: (v) {
            form.enabled = v ?? false;
            onChanged();
          },
        ),
        title: Text(network.displayName),
        subtitle: Text(form.enabled ? 'enabled' : 'disabled'),
        childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
        children: [
          Row(
            children: [
              const Text('Test mode: '),
              const SizedBox(width: 8),
              SegmentedButton<bool?>(
                showSelectedIcon: false,
                segments: const [
                  ButtonSegment(value: null, label: Text('Global')),
                  ButtonSegment(value: true, label: Text('On')),
                  ButtonSegment(value: false, label: Text('Off')),
                ],
                selected: {form.testMode},
                onSelectionChanged: (s) {
                  form.testMode = s.first;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          field(form.appId, _appIdLabel),
          field(form.banner, 'Banner $_unitLabel'),
          field(form.interstitial, 'Interstitial $_unitLabel'),
          field(form.rewarded, 'Rewarded $_unitLabel'),
          field(form.rewardedInterstitial, 'Rewarded interstitial $_unitLabel'),
          field(form.appOpen, 'App open $_unitLabel'),
          field(form.testDevices, 'Test device IDs (comma separated)'),
        ],
      ),
    );
  }
}
