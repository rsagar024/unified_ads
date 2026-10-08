import 'dart:async';

import 'package:flutter/material.dart';
import 'package:unified_ads/unified_ads.dart';

import 'src/ads_controller.dart';
import 'src/ads_screen.dart';
import 'src/event_log.dart';
import 'src/log_screen.dart';
import 'src/settings_screen.dart';
import 'src/test_credentials.dart';

/// Google's public AdMob demo configuration (used by the integration test).
final NetworkConfig admobTestConfig = TestCredentials.admob;

void main() {
  runApp(const DemoApp());
}

/// The unified_ads example: an **Ads** tab with buttons per network, a
/// **Settings** tab to enter IDs, and a live **Log** tab.
class DemoApp extends StatelessWidget {
  /// Creates the app.
  const DemoApp({super.key, this.autoInit = true});

  /// Whether to run ATT → consent → init on start (disabled in widget tests).
  final bool autoInit;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'unified_ads demo',
      theme: ThemeData(colorSchemeSeed: Colors.indigo, useMaterial3: true),
      home: HomeShell(autoInit: autoInit),
    );
  }
}

/// Bottom navigation between the Ads, Settings and Log tabs.
class HomeShell extends StatefulWidget {
  /// Creates the shell.
  const HomeShell({super.key, this.autoInit = true});

  /// Whether to initialize ads on start.
  final bool autoInit;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late final EventLog _log = EventLog(events: UnifiedAds.events);
  late final AdsController _controller = AdsController(log: _log);
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    UnifiedAds.logger = const AdsLogger.console(level: AdsLogLevel.debug);
    if (widget.autoInit) unawaited(_controller.start());
  }

  @override
  void dispose() {
    _controller.dispose();
    _log.dispose();
    super.dispose();
  }

  static const _titles = ['unified_ads demo', 'Settings', 'Event log'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_titles[_tab])),
      body: IndexedStack(
        index: _tab,
        children: [
          AdsScreen(controller: _controller, log: _log),
          SettingsScreen(controller: _controller),
          LogScreen(log: _log),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: [
          const NavigationDestination(icon: Icon(Icons.ad_units), label: 'Ads'),
          const NavigationDestination(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
          NavigationDestination(
            icon: ListenableBuilder(
              listenable: _log,
              builder: (context, _) => Badge.count(
                count: _log.entries.length,
                isLabelVisible: _log.entries.isNotEmpty,
                child: const Icon(Icons.list_alt),
              ),
            ),
            label: 'Log',
          ),
        ],
      ),
    );
  }
}
