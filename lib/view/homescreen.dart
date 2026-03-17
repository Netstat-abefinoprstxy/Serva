import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sovereign/api/go_models.dart';
import 'package:sovereign/api/sovereign_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/main_bloc.dart';
import '../bloc/main_event.dart';
import '../bloc/main_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sovereign'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<MainBloc>().add(const MainLoadRequested()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<MainBloc, MainState>(
        builder: (context, state) {
          if (state is MainInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MainLoading) {
            return _LoadingView(message: state.message);
          }

          if (state is MainError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<MainBloc>().add(const MainLoadRequested()),
            );
          }

          if (state is MainLoaded) {
            return _LoadedView(
              state: state,
              onCreateService: () => _showCreateServiceSheet(context),
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateServiceSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Create service'),
      ),
    );
  }

  void _showCreateServiceSheet(BuildContext context) {
    final bloc = context.read<MainBloc>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateServiceSheet(bloc: bloc),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message ?? 'Working...'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

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
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
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

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state, required this.onCreateService});

  final MainLoaded state;
  final VoidCallback onCreateService;

  @override
  Widget build(BuildContext context) {
    final services = state.services;

    return Column(
      children: [
        _Header(healthOk: state.healthOk, lastMessage: state.lastMessage),
        const Divider(height: 1),
        Expanded(
          child: services.isEmpty
              ? _EmptyServices(onCreate: onCreateService)
              : ListView.separated(
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return _ServiceTile(service: service);
                  },
                ),
        ),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.healthOk, this.lastMessage});

  final bool healthOk;
  final String? lastMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            healthOk ? Icons.check_circle : Icons.warning_amber_rounded,
            color: healthOk ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  healthOk ? 'Daemon connected' : 'Daemon not reachable',
                  style: theme.textTheme.titleSmall,
                ),
                if (lastMessage != null && lastMessage!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      lastMessage!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyServices extends StatelessWidget {
  const _EmptyServices({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No services yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first service to confirm everything is wired up.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create service'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final GoService service;

  bool get _isRunning => service.state.toLowerCase() == 'running';
  bool get _isLanExposed => service.lanEnabled;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MainBloc>();
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        child: Icon(_isRunning ? Icons.play_arrow : Icons.stop),
      ),
      onTap: () => _showServiceDetailsSheet(context, service),
      title: Text(service.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${service.image} • ${service.status}'),
          if (service.localUrl.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                service.localUrl,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (service.lanEnabled && service.lanUrl.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                service.lanUrl,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 4,
        children: [
          if (service.localUrl.trim().isNotEmpty)
            IconButton(
              tooltip: 'Open',
              onPressed: () => _openUrl(context, service.localUrl),
              icon: const Icon(Icons.open_in_new),
            ),
          if (_isRunning)
            IconButton(
              tooltip: _isLanExposed ? 'Disable LAN access' : 'Expose to LAN',
              onPressed: () => bloc.add(MainExposeLanRequested(id: service.id, enabled: !_isLanExposed)),
              icon: Icon(
                Icons.wifi,
                color: _isLanExposed ? theme.colorScheme.primary : null,
              ),
            ),
          if (!_isRunning)
            IconButton(
              tooltip: 'Start',
              onPressed: () => bloc.add(MainStartRequested(id: service.id)),
              icon: const Icon(Icons.play_arrow),
            )
          else
            IconButton(
              tooltip: 'Stop',
              onPressed: () => bloc.add(MainStopRequested(id: service.id)),
              icon: const Icon(Icons.stop),
            ),
          IconButton(
            tooltip: 'Details',
            onPressed: () => _showServiceDetailsSheet(context, service),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}

Future<void> _showServiceDetailsSheet(BuildContext context, GoService service) async {
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
  final SovereignApi _api = SovereignApi();

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
                  return _ErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }

                final data = snapshot.data;
                if (data == null) {
                  return _ErrorView(
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
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SelectableText(
              value.isEmpty ? 'n/a' : value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
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

  Uri? uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    uri = null;
  }

  if (uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL')));
    return;
  }

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
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

class _CreateServiceSheet extends StatefulWidget {
  const _CreateServiceSheet({required this.bloc});

  final MainBloc bloc;

  @override
  State<_CreateServiceSheet> createState() => _CreateServiceSheetState();
}

class _CreateServiceSheetState extends State<_CreateServiceSheet> {
  static const templates = <({String label, String name, String image, int port})>[
    (label: 'Test (nginx)', name: 'sovereignd-test', image: 'nginx:alpine', port: 80),
    (label: 'Vaultwarden', name: 'vaultwarden', image: 'vaultwarden/server:latest', port: 80),
    (label: 'Jellyfin', name: 'jellyfin', image: 'jellyfin/jellyfin:latest', port: 8096),
    (label: 'Navidrome', name: 'navidrome', image: 'deluan/navidrome:latest', port: 4533),
    (label: 'Minecraft', name: 'minecraft', image: 'itzg/minecraft-server:latest', port: 25565),
    (label: 'Uptime Kuma', name: 'uptime-kuma', image: 'louislam/uptime-kuma:latest', port: 3001),
    (label: 'Nextcloud (Drive Alternative)', name: 'nextcloud', image: 'nextcloud:latest', port: 80),
    (label: 'Immich (Photos Alternative)', name: 'immich-server', image: 'ghcr.io/immich-app/immich-server:release', port: 2283),
    (label: 'Outline (Docs/Notion Alternative)', name: 'outline', image: 'outlinewiki/outline:latest', port: 3000),
    (label: 'Umami (Analytics Alternative)', name: 'umami', image: 'ghcr.io/umami-software/umami:latest', port: 3000),
    (label: 'Whoogle (Private Search)', name: 'whoogle', image: 'benbusby/whoogle-search:latest', port: 5000),
    (label: 'Focalboard (Project Management)', name: 'focalboard', image: 'mattermost/focalboard:latest', port: 8000),
    (label: 'Mattermost (Chat Alternative)', name: 'mattermost', image: 'mattermost/mattermost-team-edition:latest', port: 8065),
    (label: 'Gitea (Git Server)', name: 'gitea', image: 'gitea/gitea:latest', port: 3000),
    (label: 'NocoDB (Airtable Alternative)', name: 'nocodb', image: 'nocodb/nocodb:latest', port: 8080),
    (label: 'Adminer (Database Viewer)', name: 'adminer', image: 'adminer:latest', port: 8080),
    (label: 'Grafana (Metrics Dashboard)', name: 'grafana', image: 'grafana/grafana:latest', port: 3000),
  ];

  final _nameCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '80');
  final _formKey = GlobalKey<FormState>();

  int _selectedTemplate = 0;

  @override
  void initState() {
    super.initState();
    _applyTemplate(_selectedTemplate);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imageCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  String _suggestNameFromImage(String image) {
    var base = image.trim();
    if (base.isEmpty) return 'service';

    base = base.replaceAll(RegExp(r'^docker\s+pull\s+', caseSensitive: false), '').trim();

    if ((base.startsWith('"') && base.endsWith('"')) || (base.startsWith("'") && base.endsWith("'"))) {
      base = base.substring(1, base.length - 1);
    }

    final slash = base.lastIndexOf('/');
    if (slash >= 0 && slash < base.length - 1) {
      base = base.substring(slash + 1);
    }

    final colon = base.indexOf(':');
    if (colon > 0) base = base.substring(0, colon);
    final at = base.indexOf('@');
    if (at > 0) base = base.substring(0, at);

    base = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    base = base.replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isEmpty) base = 'service';

    final suffix = Random().nextInt(9000) + 1000;
    return '$base-$suffix';
  }

  String? _extractImageFromPaste(String input) {
    final text = input.trim();
    if (text.isEmpty) return null;

    final pull = RegExp(r'\bdocker\s+pull\s+([^\s]+)', caseSensitive: false);
    final match = pull.firstMatch(text);
    if (match != null) {
      return match.group(1)?.trim();
    }

    if (!text.contains(' ') && (text.contains('/') || text.contains(':'))) {
      return text;
    }

    return null;
  }

  Future<void> _openDockerHubSearch() async {
    final uri = Uri.parse('https://hub.docker.com/search');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Docker Hub')),
      );
    }
  }

  Future<void> _pasteImageOrCommand() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';

    final image = _extractImageFromPaste(text);
    if (image == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard does not look like an image or `docker pull <image>` command.'),
        ),
      );
      return;
    }

    setState(() {
      _imageCtrl.text = image;
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = _suggestNameFromImage(image);
      }
    });
  }

  void _applyTemplate(int index) {
    final template = templates[index];
    final suffix = Random().nextInt(9000) + 1000;
    _nameCtrl.text = '${template.name}-$suffix';
    _imageCtrl.text = template.image;
    _portCtrl.text = template.port.toString();
  }

  void _createService() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    Navigator.of(context).pop();
    widget.bloc.add(
      MainCreateServiceRequested(
        name: _nameCtrl.text.trim(),
        image: _imageCtrl.text.trim(),
        containerPort: int.parse(_portCtrl.text.trim()),
      ),
    );
  }

  void _createTest() {
    Navigator.of(context).pop();
    widget.bloc.add(const MainCreateTestRequested());
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Create service', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Docker Hub',
                onPressed: _openDockerHubSearch,
                icon: const Icon(Icons.travel_explore),
              ),
              IconButton(
                tooltip: 'Paste image/command',
                onPressed: _pasteImageOrCommand,
                icon: const Icon(Icons.content_paste),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text('Template', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedTemplate,
            items: [
              for (var i = 0; i < templates.length; i++)
                DropdownMenuItem<int>(
                  value: i,
                  child: Text(templates[i].label),
                ),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _selectedTemplate = value;
                _applyTemplate(value);
              });
            },
          ),
          const SizedBox(height: 12),
          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    hintText: 'e.g. jellyfin-1234',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Image',
                    hintText: 'e.g. nginx:alpine  (or paste: docker pull grafana/grafana)',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (value) => (value == null || value.trim().isEmpty) ? 'Image is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _portCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Container port',
                    hintText: 'e.g. 80',
                  ),
                  keyboardType: TextInputType.number,
                  validator: (value) {
                    final raw = value?.trim();
                    if (raw == null || raw.isEmpty) return 'Port is required';
                    final parsed = int.tryParse(raw);
                    if (parsed == null || parsed <= 0 || parsed > 65535) {
                      return 'Port must be 1-65535';
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _createTest,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Create test'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _createService,
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
