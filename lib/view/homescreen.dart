import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/api/sovereign_api.dart';
import 'package:url_launcher/url_launcher.dart';

import '../bloc/main_bloc.dart';
import '../bloc/main_event.dart';
import '../bloc/main_state.dart';

const _dockerDesktopStoreUrl = 'https://apps.microsoft.com/detail/xp8cbj40xlbwkx?hl=en-GB&gl=GB';
const _virtualizationHelpUrl =
    'https://support.microsoft.com/en-us/windows/enable-virtualization-on-windows-c5578302-6e43-4b4b-a449-8ced115f58e1';
const _forceVirtualizationHelpPreview = false;

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Serva'),
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
    final dockerUnavailable = _looksLikeDockerUnavailable(message);
    final virtualizationIssue = _looksLikeVirtualizationIssue(message);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              virtualizationIssue
                  ? 'Docker Desktop needs virtualization enabled to run.\n\nTurn on virtualization in Windows and, if needed, enable virtualization in your BIOS/UEFI settings first, then retry.'
                  : dockerUnavailable
                  ? 'Docker Desktop is required before Serva can manage services.\n\nInstall or start Docker Desktop, then retry.'
                  : message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (virtualizationIssue) ...[
              FilledButton.icon(
                onPressed: () => _openUrl(context, _virtualizationHelpUrl),
                icon: const Icon(Icons.memory),
                label: const Text('Enable Virtualization'),
              ),
              const SizedBox(height: 12),
            ],
            if (dockerUnavailable) ...[
              FilledButton.icon(
                onPressed: () => _openUrl(context, _dockerDesktopStoreUrl),
                icon: const Icon(Icons.download),
                label: const Text('Get Docker Desktop'),
              ),
              const SizedBox(height: 12),
            ],
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
    final activeDefinitionIds = services.map((service) => service.name).toSet();
    final savedDefinitions = state.definitions
        .where((definition) => !activeDefinitionIds.contains(definition.name))
        .toList();

    return Column(
      children: [
        _Header(healthOk: state.healthOk, lastMessage: state.lastMessage),
        const Divider(height: 1),
        Expanded(
          child: services.isEmpty && savedDefinitions.isEmpty
              ? _EmptyServices(onCreate: onCreateService)
              : ListView(
                  children: [
                    if (services.isNotEmpty) ...[
                      const _SectionTitle(title: 'Live Services'),
                      for (final service in services) ...[
                        _ServiceTile(service: service),
                        const Divider(height: 1),
                      ],
                    ],
                    if (savedDefinitions.isNotEmpty) ...[
                      const _SectionTitle(title: 'Saved Definitions'),
                      for (final definition in savedDefinitions) ...[
                        _SavedDefinitionTile(definition: definition),
                        const Divider(height: 1),
                      ],
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
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
    final dockerUnavailable = _looksLikeDockerUnavailable(lastMessage);
    final virtualizationIssue = _looksLikeVirtualizationIssue(lastMessage);

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
                  healthOk
                      ? 'Daemon connected'
                      : virtualizationIssue
                      ? 'Virtualization required'
                      : dockerUnavailable
                      ? 'Docker Desktop required'
                      : 'Daemon not reachable',
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
                if (dockerUnavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _openUrl(context, _dockerDesktopStoreUrl),
                        icon: const Icon(Icons.download),
                        label: const Text('Install Docker Desktop'),
                      ),
                    ),
                  ),
                if (virtualizationIssue)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You may need to enable virtualization inside your BIOS/UEFI before Docker Desktop can start.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openUrl(context, _virtualizationHelpUrl),
                          icon: const Icon(Icons.memory),
                          label: const Text('Virtualization Help'),
                        ),
                      ],
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

bool _looksLikeDockerUnavailable(String? message) {
  if (message == null || message.trim().isEmpty) {
    return false;
  }

  final normalized = message.toLowerCase();
  return normalized.contains('docker') ||
      normalized.contains('health check failed') ||
      normalized.contains('connection refused') ||
      normalized.contains('actively refused') ||
      normalized.contains('daemon not reachable');
}

bool _looksLikeVirtualizationIssue(String? message) {
  if (_forceVirtualizationHelpPreview) {
    return true;
  }

  if (message == null || message.trim().isEmpty) {
    return false;
  }

  final normalized = message.toLowerCase();
  return normalized.contains('virtualization') ||
      normalized.contains('hyper-v') ||
      normalized.contains('hyperv') ||
      normalized.contains('wsl') ||
      normalized.contains('bios') ||
      normalized.contains('uefi') ||
      normalized.contains('hardware assisted virtualization') ||
      normalized.contains('required feature is not installed') ||
      normalized.contains('vmx') ||
      normalized.contains('svm');
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

class _SavedDefinitionTile extends StatelessWidget {
  const _SavedDefinitionTile({required this.definition});

  final GoServiceDefinition definition;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MainBloc>();

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.save_outlined)),
      title: Text(definition.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${definition.image} • saved definition'),
          if (definition.mounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${definition.mounts.length} persistent mount${definition.mounts.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      isThreeLine: definition.mounts.isNotEmpty,
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Recreate',
            onPressed: () => bloc.add(MainRecreateRequested(id: definition.id)),
            icon: const Icon(Icons.restore),
          ),
          IconButton(
            tooltip: 'Details',
            onPressed: () => _showDefinitionDetailsSheet(context, definition),
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

Future<void> _showDefinitionDetailsSheet(BuildContext context, GoServiceDefinition definition) async {
  final bloc = context.read<MainBloc>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.75,
      child: _DefinitionDetailsSheet(definition: definition, bloc: bloc),
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

class _DefinitionDetailsSheet extends StatelessWidget {
  const _DefinitionDetailsSheet({required this.definition, required this.bloc});

  final GoServiceDefinition definition;
  final MainBloc bloc;

  Future<void> _confirmDelete(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved definition?'),
        content: const Text(
          'You can remove just the saved definition, or also delete any persistent data marked as managed by Serva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('definition'),
            child: const Text('Delete definition'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('definition+data'),
            child: const Text('Delete with data'),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    Navigator.of(context).pop();
    bloc.add(
      MainDeleteDefinitionRequested(
        id: definition.id,
        deleteData: choice == 'definition+data',
      ),
    );
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
                    Text(definition.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(definition.image, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  bloc.add(MainRecreateRequested(id: definition.id));
                },
                icon: const Icon(Icons.restore),
                label: const Text('Recreate'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _DetailSection(
                  title: 'Definition',
                  child: Column(
                    children: [
                      _DetailRow(label: 'ID', value: definition.id),
                      _DetailRow(label: 'Port', value: definition.containerPort.toString()),
                      _DetailRow(label: 'Protocol', value: definition.serviceProto),
                      _DetailRow(label: 'LAN', value: definition.lanEnabled ? 'enabled' : 'disabled'),
                      _DetailRow(
                        label: 'Current container',
                        value: definition.currentContainerId.isEmpty ? 'not deployed' : _shortId(definition.currentContainerId),
                      ),
                      _DetailRow(
                        label: 'Last host port',
                        value: definition.lastKnownHostPort == 0 ? 'n/a' : definition.lastKnownHostPort.toString(),
                      ),
                      _DetailRow(label: 'Created', value: definition.createdAt),
                      _DetailRow(label: 'Updated', value: definition.updatedAt),
                    ],
                  ),
                ),
                _DetailSection(
                  title: 'Persistent Mounts',
                  child: definition.mounts.isEmpty
                      ? const Text('No persistent mounts configured yet.')
                      : Column(
                          children: definition.mounts
                              .map(
                                (mount) => _DetailRow(
                                  label: mount.target,
                                  value:
                                      '${mount.source} (${mount.type}${mount.readOnly ? ', read-only' : ''}${mount.managed ? ', managed' : ''})',
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
              ],
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
  const _DetailRow({required this.label, required this.value, this.trailing});

  final String label;
  final String value;
  final Widget? trailing;

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
  final _mountSourceCtrl = TextEditingController();
  final _mountTargetCtrl = TextEditingController();
  final List<GoServiceDefinitionMount> _mounts = [];

  int _selectedTemplate = 0;
  bool _mountReadOnly = false;
  bool _mountManaged = true;
  String _mountType = 'bind';

  String get _defaultManagedBasePath {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return '$userProfile\\Documents\\Serva';
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}Serva';
    }

    return 'Documents${Platform.pathSeparator}Serva';
  }

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
    _mountSourceCtrl.dispose();
    _mountTargetCtrl.dispose();
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
        final suggested = _suggestNameFromImage(image);
        _nameCtrl.text = suggested;
        if (_mounts.isEmpty &&
            (_mountSourceCtrl.text.trim().isEmpty || _mountSourceCtrl.text.startsWith(_defaultManagedBasePath))) {
          _mountSourceCtrl.text = '${_defaultMountRootForName(suggested)}\\data';
        }
      }
    });
  }

  void _applyTemplate(int index) {
    final template = templates[index];
    final suffix = Random().nextInt(9000) + 1000;
    final serviceName = '${template.name}-$suffix';
    _nameCtrl.text = serviceName;
    _imageCtrl.text = template.image;
    _portCtrl.text = template.port.toString();
    _mounts
      ..clear()
      ..addAll(_defaultMountsForTemplate(template.name, serviceName));
    _mountSourceCtrl.clear();
    _mountTargetCtrl.clear();
    _mountReadOnly = false;
    _mountManaged = true;
    _mountType = 'bind';
  }

  String _defaultMountRootForName(String serviceName) {
    final sanitized = serviceName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
    return '$_defaultManagedBasePath\\$sanitized';
  }

  List<String> _defaultMountTargetsForTemplate(String templateName) {
    switch (templateName) {
      case 'navidrome':
        return const ['/data', '/music'];
      case 'uptime-kuma':
        return const ['/app/data'];
      case 'vaultwarden':
        return const ['/data'];
      case 'grafana':
        return const ['/var/lib/grafana'];
      case 'nextcloud':
        return const ['/var/www/html'];
      case 'jellyfin':
        return const ['/config'];
      case 'gitea':
        return const ['/data'];
      default:
        return const ['/data'];
    }
  }

  List<GoServiceDefinitionMount> _defaultMountsForTemplate(String templateName, String serviceName) {
    final root = _defaultMountRootForName(serviceName);
    return _defaultMountTargetsForTemplate(templateName)
        .map(
          (target) => GoServiceDefinitionMount(
            type: 'bind',
            source: '$root\\${_subfolderNameForTarget(target)}',
            target: target,
            readOnly: false,
            managed: true,
          ),
        )
        .toList();
  }

  String _subfolderNameForTarget(String target) {
    final segments = target.split('/').where((segment) => segment.trim().isNotEmpty).toList();
    if (segments.isEmpty) {
      return 'data';
    }
    return segments.join('-');
  }

  void _createService() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final mounts = List<GoServiceDefinitionMount>.from(_mounts);
    final draftSource = _mountSourceCtrl.text.trim();
    final draftTarget = _mountTargetCtrl.text.trim();
    if (draftSource.isNotEmpty && draftTarget.isNotEmpty) {
      mounts.add(
        GoServiceDefinitionMount(
          type: _mountType,
          source: draftSource,
          target: draftTarget,
          readOnly: _mountReadOnly,
          managed: _mountManaged,
        ),
      );
    }

    Navigator.of(context).pop();
    widget.bloc.add(
      MainCreateServiceRequested(
        name: _nameCtrl.text.trim(),
        image: _imageCtrl.text.trim(),
        containerPort: int.parse(_portCtrl.text.trim()),
        mounts: mounts,
      ),
    );
  }

  void _addMount() {
    final source = _mountSourceCtrl.text.trim();
    final target = _mountTargetCtrl.text.trim();
    if (source.isEmpty || target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both mount source and target are required.')),
      );
      return;
    }

    setState(() {
      _mounts.add(
        GoServiceDefinitionMount(
          type: _mountType,
          source: source,
          target: target,
          readOnly: _mountReadOnly,
          managed: _mountManaged,
        ),
      );
      _mountSourceCtrl.clear();
      _mountTargetCtrl.clear();
      _mountReadOnly = false;
      _mountManaged = true;
      _mountType = 'bind';
    });
  }

  void _removeMount(int index) {
    setState(() {
      _mounts.removeAt(index);
    });
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
          Text('Persistent mounts', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          if (_mounts.isNotEmpty)
            Container(
              constraints: const BoxConstraints(maxHeight: 180),
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: _mounts.length,
                itemBuilder: (context, index) {
                  final mount = _mounts[index];
                  return ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text('${mount.source} → ${mount.target}'),
                    subtitle: Text(
                      '${mount.type}${mount.readOnly ? ' • read-only' : ''}${mount.managed ? ' • managed' : ''}',
                    ),
                    trailing: IconButton(
                      tooltip: 'Remove mount',
                      onPressed: () => _removeMount(index),
                      icon: const Icon(Icons.close),
                    ),
                  );
                },
              ),
            ),
          DropdownButtonFormField<String>(
            value: _mountType,
            decoration: const InputDecoration(labelText: 'Mount type'),
            items: const [
              DropdownMenuItem(value: 'bind', child: Text('Host path bind')),
              DropdownMenuItem(value: 'volume', child: Text('Docker volume')),
            ],
            onChanged: (value) {
              if (value == null) return;
              setState(() {
                _mountType = value;
              });
            },
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mountSourceCtrl,
            decoration: InputDecoration(
              labelText: _mountType == 'bind' ? 'Source path' : 'Volume name',
              hintText: _mountType == 'bind' ? r'e.g. C:\Users\you\Documents\Serva\vaultwarden' : 'e.g. serva-vaultwarden-data',
            ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _mountTargetCtrl,
            decoration: const InputDecoration(
              labelText: 'Container target',
              hintText: 'e.g. /data',
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Read-only'),
            value: _mountReadOnly,
            onChanged: (value) {
              setState(() {
                _mountReadOnly = value;
              });
            },
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Managed by Serva'),
            subtitle: const Text('Marks this mount as part of the durable service definition.'),
            value: _mountManaged,
            onChanged: (value) {
              setState(() {
                _mountManaged = value;
              });
            },
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: _addMount,
              icon: const Icon(Icons.add_link),
              label: const Text('Add mount'),
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
