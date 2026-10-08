import 'package:flutter/material.dart';
import 'package:unified_ads/unified_ads.dart';

import 'event_log.dart';

/// The live event console: every callback with a timestamp, filterable by
/// network and errors, and clearable.
class LogScreen extends StatefulWidget {
  /// Creates the screen.
  const LogScreen({required this.log, super.key});

  /// The log to show.
  final EventLog log;

  @override
  State<LogScreen> createState() => _LogScreenState();
}

class _LogScreenState extends State<LogScreen> {
  AdNetwork? _network;
  bool _errorsOnly = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListenableBuilder(
      listenable: widget.log,
      builder: (context, _) {
        final entries = [
          for (final e in widget.log.entries)
            if ((_network == null || e.network == _network) &&
                (!_errorsOnly || e.isError))
              e,
        ];
        return Column(
          children: [
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
              child: Row(
                children: [
                  ChoiceChip(
                    label: const Text('All'),
                    selected: _network == null,
                    onSelected: (_) => setState(() => _network = null),
                  ),
                  for (final n in AdNetwork.values)
                    Padding(
                      padding: const EdgeInsets.only(left: 6),
                      child: ChoiceChip(
                        label: Text(n.id),
                        selected: _network == n,
                        onSelected: (_) => setState(() => _network = n),
                      ),
                    ),
                ],
              ),
            ),
            Row(
              children: [
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Errors only'),
                  selected: _errorsOnly,
                  onSelected: (v) => setState(() => _errorsOnly = v),
                ),
                const Spacer(),
                Text('${entries.length} event(s)'),
                IconButton(
                  tooltip: 'Clear',
                  onPressed: widget.log.clear,
                  icon: const Icon(Icons.delete_sweep),
                ),
              ],
            ),
            const Divider(height: 1),
            Expanded(
              child: entries.isEmpty
                  ? const Center(child: Text('No events yet'))
                  : ListView.separated(
                      itemCount: entries.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, i) {
                        final e = entries[i];
                        final where = [
                          if (e.network != null) e.network!.id,
                          if (e.format != null) e.format!.id,
                        ].join(' · ');
                        return ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          title: Text(
                            '${e.timestamp}  ${e.kind}'
                            '${where.isEmpty ? '' : '  [$where]'}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              fontFamily: 'monospace',
                              color: e.isError ? theme.colorScheme.error : null,
                            ),
                          ),
                          subtitle: Text(e.message),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
