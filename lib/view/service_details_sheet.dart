import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/api/sovereign_api.dart';
import 'package:serva/bloc/main_bloc.dart';
import 'package:serva/bloc/main_event.dart';
import 'package:url_launcher/url_launcher.dart';

Future<void> showServiceDetailsSheet(BuildContext context, GoService service) async {
  final bloc = context.read<MainBloc>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _ServiceDetailsSheet(service: service, bloc: bloc),
    ),
  );
}

class _ServiceDetailsSheet extends StatefulWidget {
  const _ServiceDetailsSheet({required this.service, required this.bloc});

  final GoService service;
  final MainBloc bloc;

  @override
  State<_ServiceDetailsSheet> createState() => _ServiceDetailsSheetState();
}

class _ServiceDetailsSheetState extends State<_ServiceDetailsSheet> {
  final ServaApi _api = ServaApi();

  late Future<_ServiceDetailsData> _future;

  bool get _isRunning => widget.service.state.toLowerCase() == 'running';

  @override
  void initState() {
    super.initState();
    _future = _loadDetails();
  }

  Future<_ServiceDetailsData> _loadDetails() async {
    final inspect = await _api.serviceInspect(widget.service.id);
    final stats = await _api.serviceStats(widget.service.id);
    final logs = await _api.serviceLogs(widget.service.id);
    return _ServiceDetailsData(inspect: inspect, stats: stats, logs: logs);
  }

  void _refresh() {
    setState(() {
      _future = _loadDetails();
    });
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove service?'),
        content: Text('This will force-remove "${widget.service.name}".'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      widget.bloc.add(MainRemoveRequested(id: widget.service.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.service.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(widget.service.image, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh details',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (widget.service.localUrl.trim().isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: () => _openUrl(context, widget.service.localUrl),
                  icon: const Icon(Icons.open_in_new),
                  label: const Text('Open local'),
                ),
              if (widget.service.lanUrl.trim().isNotEmpty)
                FilledButton.tonalIcon(
                  onPressed: () => _openUrl(context, widget.service.lanUrl),
                  icon: const Icon(Icons.wifi),
                  label: const Text('Open LAN'),
                ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.bloc.add(MainRestartRequested(id: widget.service.id));
                },
                icon: const Icon(Icons.restart_alt),
                label: const Text('Restart'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  if (_isRunning) {
                    widget.bloc.add(MainStopRequested(id: widget.service.id));
                  } else {
                    widget.bloc.add(MainStartRequested(id: widget.service.id));
                  }
                },
                icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
                label: Text(_isRunning ? 'Stop' : 'Start'),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  widget.bloc.add(
                    MainExposeLanRequested(id: widget.service.id, enabled: !widget.service.lanEnabled),
                  );
                },
                icon: const Icon(Icons.settings_ethernet),
                label: Text(widget.service.lanEnabled ? 'Disable LAN' : 'Enable LAN'),
              ),
              FilledButton.tonalIcon(
                onPressed: _confirmRemove,
                icon: const Icon(Icons.delete_outline),
                label: const Text('Remove'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<_ServiceDetailsData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _DetailErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }

                final data = snapshot.data;
                if (data == null) {
                  return _DetailErrorView(
                    message: 'No details available.',
                    onRetry: _refresh,
                  );
                }

                return ListView(
                  children: [
                    _DetailSection(
                      title: 'Overview',
                      child: Column(
                        children: [
                          _DetailRow(label: 'State', value: data.inspect.state),
                          _DetailRow(label: 'Status', value: data.inspect.status),
                          _DetailRow(label: 'Container ID', value: _shortId(data.inspect.id)),
                          _DetailRow(label: 'Created', value: data.inspect.created),
                          _DetailRow(
                            label: 'Restart policy',
                            value: data.inspect.restartPolicy.isEmpty ? 'none' : data.inspect.restartPolicy,
                          ),
                          _DetailRow(label: 'Path', value: data.inspect.path),
                          if (data.inspect.localUrl.trim().isNotEmpty)
                            _DetailRow(label: 'Local URL', value: data.inspect.localUrl),
                          if (data.inspect.lanUrl.trim().isNotEmpty)
                            _DetailRow(label: 'LAN URL', value: data.inspect.lanUrl),
                        ],
                      ),
                    ),
                    _DetailSection(
                      title: 'Ports',
                      child: data.inspect.ports.isEmpty
                          ? const Text('No published ports.')
                          : Column(
                              children: data.inspect.ports
                                  .map(
                                    (port) => _DetailRow(
                                      label: port.containerRef,
                                      value: port.publicPort > 0
                                          ? '${port.ip.isEmpty ? '0.0.0.0' : port.ip}:${port.publicPort}'
                                          : 'container-only',
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    _DetailSection(
                      title: 'Stats',
                      child: Column(
                        children: [
                          _DetailRow(label: 'Read at', value: data.stats.readAt.isEmpty ? 'n/a' : data.stats.readAt),
                          _DetailRow(
                            label: 'CPU total',
                            value: _nestedValueAsString(data.stats.raw, const ['cpu_stats', 'cpu_usage', 'total_usage']),
                          ),
                          _DetailRow(
                            label: 'Memory usage',
                            value: _nestedValueAsString(data.stats.raw, const ['memory_stats', 'usage']),
                          ),
                          _DetailRow(
                            label: 'Memory limit',
                            value: _nestedValueAsString(data.stats.raw, const ['memory_stats', 'limit']),
                          ),
                          _DetailRow(
                            label: 'Network rx bytes',
                            value: _sumNestedMapField(data.stats.raw['networks'], 'rx_bytes'),
                          ),
                          _DetailRow(
                            label: 'Network tx bytes',
                            value: _sumNestedMapField(data.stats.raw['networks'], 'tx_bytes'),
                          ),
                        ],
                      ),
                    ),
                    _DetailSection(
                      title: 'Logs',
                      trailing: IconButton(
                        tooltip: 'Copy logs',
                        onPressed: () async {
                          await Clipboard.setData(ClipboardData(text: data.logs.logs));
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Logs copied')),
                          );
                        },
                        icon: const Icon(Icons.copy_all),
                      ),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: SelectableText(
                          data.logs.logs.trim().isEmpty ? 'No logs returned.' : data.logs.logs,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'Courier'),
                        ),
                      ),
                    ),
                    _DetailSection(
                      title: 'Environment',
                      child: data.inspect.env.isEmpty
                          ? const Text('No environment variables reported.')
                          : Column(
                              children: data.inspect.env
                                  .map((entry) => _DetailRow(label: 'ENV', value: entry))
                                  .toList(),
                            ),
                    ),
                    _DetailSection(
                      title: 'Mounts',
                      child: data.inspect.mounts.isEmpty
                          ? const Text('No mounts reported.')
                          : Column(
                              children: data.inspect.mounts
                                  .map(
                                    (mount) => _DetailRow(
                                      label: mount.destination,
                                      value: '${mount.source} (${mount.type}${mount.readOnly ? ', read-only' : ''})',
                                      trailing: mount.type.toLowerCase() == 'bind'
                                          ? IconButton(
                                              tooltip: 'Open folder',
                                              onPressed: () => _openDirectory(context, mount.source),
                                              icon: const Icon(Icons.folder_open),
                                            )
                                          : null,
                                    ),
                                  )
                                  .toList(),
                            ),
                    ),
                    _DetailSection(
                      title: 'Labels',
                      child: data.inspect.labels.isEmpty
                          ? const Text('No labels reported.')
                          : Column(
                              children: data.inspect.labels.entries
                                  .map((entry) => _DetailRow(label: entry.key, value: entry.value))
                                  .toList(),
                            ),
                    ),
                    const SizedBox(height: 32),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(title, style: Theme.of(context).textTheme.titleMedium),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _ServiceDetailsData {
  const _ServiceDetailsData({
    required this.inspect,
    required this.stats,
    required this.logs,
  });

  final GoInspectResponse inspect;
  final GoStatsResponse stats;
  final GoLogsResponse logs;
}

Future<void> _openUrl(BuildContext context, String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return;

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
  }
}

Future<void> _openDirectory(BuildContext context, String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return;

  try {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [trimmed]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [trimmed]);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [trimmed]);
    } else {
      throw UnsupportedError('Opening folders is not supported on this platform.');
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open folder: $error')),
    );
  }
}

String _shortId(String id) => id.length <= 12 ? id : id.substring(0, 12);

String _nestedValueAsString(Map<String, dynamic> root, List<String> path) {
  dynamic current = root;
  for (final segment in path) {
    if (current is Map<String, dynamic>) {
      current = current[segment];
    } else if (current is Map) {
      current = current[segment];
    } else {
      return 'n/a';
    }
  }

  return current?.toString() ?? 'n/a';
}

String _sumNestedMapField(dynamic raw, String field) {
  if (raw is! Map) return 'n/a';

  var total = 0.0;
  var found = false;
  for (final value in raw.values) {
    if (value is Map && value[field] is num) {
      total += (value[field] as num).toDouble();
      found = true;
    }
  }

  if (!found) return 'n/a';
  return total % 1 == 0 ? total.toInt().toString() : total.toStringAsFixed(2);
}
