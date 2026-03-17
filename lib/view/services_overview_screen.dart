import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/api/sovereign_api.dart';
import 'package:serva/bloc/main_bloc.dart';
import 'package:serva/bloc/main_event.dart';
import 'package:serva/bloc/main_state.dart';
import 'package:url_launcher/url_launcher.dart';

import 'service_details_sheet.dart';
import 'template_gallery_screen.dart';

class ServicesOverviewScreen extends StatefulWidget {
  const ServicesOverviewScreen({
    super.key,
    required this.state,
    required this.legacyModeEnabled,
    required this.onLegacyModeChanged,
  });

  final MainLoaded state;
  final bool legacyModeEnabled;
  final ValueChanged<bool> onLegacyModeChanged;

  @override
  State<ServicesOverviewScreen> createState() => _ServicesOverviewScreenState();
}

class _ServicesOverviewScreenState extends State<ServicesOverviewScreen> {
  final ServaApi _api = ServaApi();
  late Future<_ServicesMetrics> _metricsFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _loadMetrics();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      _refreshLocalMetrics();
    });
  }

  @override
  void didUpdateWidget(covariant ServicesOverviewScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.services != widget.state.services ||
        oldWidget.state.definitions != widget.state.definitions) {
      _metricsFuture = _loadMetrics();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  void _refreshLocalMetrics() {
    if (!mounted) return;
    setState(() {
      _metricsFuture = _loadMetrics();
    });
  }

  Future<_ServicesMetrics> _loadMetrics() async {
    final services = widget.state.services;
    final definitions = widget.state.definitions;
    final statsEntries = await Future.wait(
      services.map((service) async {
        try {
          return MapEntry(service, await _api.serviceStats(service.id));
        } catch (_) {
          return null;
        }
      }),
    );

    final liveMetrics = <String, _ServiceLiveMetrics>{};
    for (final entry in statsEntries.whereType<MapEntry<GoService, GoStatsResponse>>()) {
      liveMetrics[entry.key.id] = _ServiceLiveMetrics(
        cpuPercent: _cpuPercentFromStats(entry.value.raw),
        memoryUsageBytes: _memoryUsageBytesFromStats(entry.value.raw),
        memoryLimitBytes: _memoryLimitBytesFromStats(entry.value.raw),
        networkRxBytes: _networkRxBytesFromStats(entry.value.raw),
        networkTxBytes: _networkTxBytesFromStats(entry.value.raw),
      );
    }

    final serviceStorageBytes = await _loadServaStorageMetrics(definitions);
    final serviceMountRoots = <String, String>{};
    final dataEntriesByRoot = <String, _DataEntry>{};
    final servaRoot = _servaLocalDataPath();

    dataEntriesByRoot[servaRoot] = _DataEntry(
      serviceId: '',
      serviceName: 'Serva Local Data',
      image: 'Shared Serva storage',
      rootPath: servaRoot,
      isDeployed: false,
      mounts: const [],
      isOrphaned: false,
      isGlobalRoot: true,
    );

    for (final definition in definitions) {
      final root = _serviceMountRootFromDefinition(definition);
      if (root != null && root.isNotEmpty) {
        serviceMountRoots[definition.name] = root;
      }

      final dataRoot = _dataRootFromDefinition(definition);
      if (dataRoot != null) {
        dataEntriesByRoot[dataRoot] = _DataEntry(
          serviceId: definition.id,
          serviceName: definition.name,
          image: definition.image,
          rootPath: dataRoot,
          isDeployed: definition.isDeployed,
          mounts: definition.mounts
              .where((mount) => mount.managed && mount.type.trim().toLowerCase() == 'bind')
              .toList(),
          isOrphaned: false,
          isGlobalRoot: false,
        );
      }
    }

    for (final orphanRoot in _discoverServaDataRoots()) {
      dataEntriesByRoot.putIfAbsent(
        orphanRoot,
        () {
          final folderName = orphanRoot.split(RegExp(r'[\\/]')).last.trim();
          return _DataEntry(
            serviceId: '',
            serviceName: folderName.isEmpty ? 'Unlinked data' : folderName,
            image: 'No saved definition',
            rootPath: orphanRoot,
            isDeployed: false,
            mounts: const [],
            isOrphaned: true,
            isGlobalRoot: false,
          );
        },
      );
    }

    final dataEntries = dataEntriesByRoot.values.toList()
      ..sort((a, b) {
        if (a.isGlobalRoot != b.isGlobalRoot) {
          return a.isGlobalRoot ? -1 : 1;
        }
        if (a.isOrphaned != b.isOrphaned) {
          return a.isOrphaned ? 1 : -1;
        }
        return a.serviceName.toLowerCase().compareTo(b.serviceName.toLowerCase());
      });

    final dataFolderSizes = await _loadFolderSizes(
      dataEntries.map((entry) => entry.rootPath).toSet().toList(),
    );
    final miscSubfolders = _loadMiscSubfolders(dataEntries);

    return _ServicesMetrics(
      liveMetrics: liveMetrics,
      serviceStorageBytes: serviceStorageBytes,
      serviceMountRoots: serviceMountRoots,
      dataEntries: dataEntries
          .map(
            (entry) => entry.copyWith(
              sizeBytes: dataFolderSizes[entry.rootPath] ?? 0,
              miscSubfolders: miscSubfolders[entry.rootPath] ?? const [],
            ),
          )
          .toList(),
    );
  }

  List<String> _discoverServaDataRoots() {
    final base = Directory(_servaManagedBasePath());
    if (!base.existsSync()) {
      return const [];
    }

    try {
      return base
          .listSync(followLinks: false)
          .whereType<Directory>()
          .where((directory) => _folderLeafName(directory.path).toLowerCase() != 'serva-local')
          .map((directory) => directory.path)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, double>> _loadFolderSizes(List<String> roots) async {
    if (roots.isEmpty) return const {};

    final command = StringBuffer()..writeln("\$folders = [ordered]@{}");
    for (final root in roots) {
      command
        ..writeln("\$folderPath = '${_psEscape(root)}'")
        ..writeln("if (Test-Path -LiteralPath \$folderPath) {")
        ..writeln("  \$sum = (Get-ChildItem -LiteralPath \$folderPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum")
        ..writeln("  \$folders['${_psEscape(root)}'] = if (\$null -eq \$sum) { 0 } else { [double]\$sum }")
        ..writeln("} else {")
        ..writeln("  \$folders['${_psEscape(root)}'] = 0")
        ..writeln("}");
    }
    command.writeln("\$folders | ConvertTo-Json -Compress");

    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', command.toString()],
      );
      if (result.exitCode != 0) return const {};
      final raw = result.stdout.toString().trim();
      if (raw.isEmpty) return const {};
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      final values = <String, double>{};
      for (final entry in json.entries) {
        values[entry.key.toString()] = _asDouble(entry.value);
      }
      return values;
    } catch (_) {
      return const {};
    }
  }

  Map<String, List<String>> _loadMiscSubfolders(List<_DataEntry> dataEntries) {
    final result = <String, List<String>>{};

    for (final entry in dataEntries) {
      GoServiceDefinitionMount? miscMount;
      for (final mount in entry.mounts) {
        if (mount.target.trim() == '/misc') {
          miscMount = mount;
          break;
        }
      }
      if (miscMount == null) {
        result[entry.rootPath] = const [];
        continue;
      }

      final miscRoot = Directory(miscMount.source);
      if (!miscRoot.existsSync()) {
        result[entry.rootPath] = const [];
        continue;
      }

      try {
        final folders = miscRoot
            .listSync(followLinks: false)
            .whereType<Directory>()
            .map((directory) => '/misc/${_folderLeafName(directory.path)}')
            .toList()
          ..sort();
        result[entry.rootPath] = folders;
      } catch (_) {
        result[entry.rootPath] = const [];
      }
    }

    return result;
  }

  Future<Map<String, double>> _loadServaStorageMetrics(List<GoServiceDefinition> definitions) async {
    final serviceRoots = <String, String>{};

    for (final definition in definitions) {
      final root = _serviceMountRootFromDefinition(definition);
      if (root != null && root.startsWith(_servaManagedBasePath())) {
        serviceRoots[definition.name] = root;
      }
    }

    final command = StringBuffer()..writeln("\$services = [ordered]@{}");
    serviceRoots.forEach((name, path) {
      command
        ..writeln("\$servicePath = '${_psEscape(path)}'")
        ..writeln("if (Test-Path -LiteralPath \$servicePath) {")
        ..writeln("  \$sum = (Get-ChildItem -LiteralPath \$servicePath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum")
        ..writeln("  \$services['${_psEscape(name)}'] = if (\$null -eq \$sum) { 0 } else { [double]\$sum }")
        ..writeln("} else {")
        ..writeln("  \$services['${_psEscape(name)}'] = 0")
        ..writeln("}");
    });
    command.writeln("\$services | ConvertTo-Json -Compress");

    try {
      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', command.toString()],
      );
      if (result.exitCode != 0) return const {};
      final raw = result.stdout.toString().trim();
      if (raw.isEmpty) return const {};
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      final values = <String, double>{};
      for (final entry in json.entries) {
        values[entry.key.toString()] = _asDouble(entry.value);
      }
      return values;
    } catch (_) {
      return const {};
    }
  }

  @override
  Widget build(BuildContext context) {
    final services = widget.state.services;
    final inactiveDefinitions = widget.state.definitions.where((definition) => !definition.isDeployed).toList();

    return FutureBuilder<_ServicesMetrics>(
      future: _metricsFuture,
      builder: (context, snapshot) {
        final metrics = snapshot.data;
        return ListView(
          padding: const EdgeInsets.all(8),
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFF0D1526).withValues(alpha: 0.82),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Legacy mode',
                          style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Show the older service-management tab when you need the full legacy workflow.',
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  Switch(
                    value: widget.legacyModeEnabled,
                    onChanged: widget.onLegacyModeChanged,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            _ServicesPanel(
              services: services,
              liveMetrics: metrics?.liveMetrics ?? const {},
              serviceStorageBytes: metrics?.serviceStorageBytes ?? const {},
              serviceMountRoots: metrics?.serviceMountRoots ?? const {},
            ),
            if (inactiveDefinitions.isNotEmpty) ...[
              const SizedBox(height: 8),
              _InactiveServicesPanel(definitions: inactiveDefinitions),
            ],
            if ((metrics?.dataEntries ?? const <_DataEntry>[]).isNotEmpty) ...[
              const SizedBox(height: 8),
              _DataPanel(
                dataEntries: metrics?.dataEntries ?? const [],
                onChanged: _refreshLocalMetrics,
              ),
            ],
          ],
        );
      },
    );
  }
}

class _ServicesPanel extends StatelessWidget {
  const _ServicesPanel({
    required this.services,
    required this.liveMetrics,
    required this.serviceStorageBytes,
    required this.serviceMountRoots,
  });

  final List<GoService> services;
  final Map<String, _ServiceLiveMetrics> liveMetrics;
  final Map<String, double> serviceStorageBytes;
  final Map<String, String> serviceMountRoots;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Active services', style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            'Direct controls, live metrics, and service data usage.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          if (services.isEmpty)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text('No active services yet.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1320 ? 5 : width >= 1150 ? 4 : width >= 900 ? 3 : width >= 680 ? 2 : 1;
                return GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: services.length,
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: crossAxisCount,
                    crossAxisSpacing: 8,
                    mainAxisSpacing: 8,
                    childAspectRatio: crossAxisCount == 1 ? 3.4 : crossAxisCount >= 4 ? 1.56 : crossAxisCount == 3 ? 1.72 : 2.3,
                  ),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return _ActiveServiceTile(
                      service: service,
                      liveMetrics: liveMetrics[service.id],
                      storageBytes: serviceStorageBytes[service.name],
                      mountRoot: serviceMountRoots[service.name],
                    );
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _InactiveServicesPanel extends StatelessWidget {
  const _InactiveServicesPanel({required this.definitions});

  final List<GoServiceDefinition> definitions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Inactive services', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            'Saved definitions that are not currently deployed.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1500 ? 6 : width >= 1200 ? 5 : width >= 900 ? 4 : width >= 650 ? 3 : width >= 440 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: definitions.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: crossAxisCount == 1 ? 3.6 : 2.1,
                ),
                itemBuilder: (context, index) => _InactiveServiceTile(definition: definitions[index]),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActiveServiceTile extends StatelessWidget {
  const _ActiveServiceTile({
    required this.service,
    this.liveMetrics,
    this.storageBytes,
    this.mountRoot,
  });

  final GoService service;
  final _ServiceLiveMetrics? liveMetrics;
  final double? storageBytes;
  final String? mountRoot;

  bool get _isRunning => service.state.toLowerCase() == 'running';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<MainBloc>();
    final accent = _isRunning ? const Color(0xFF80ED99) : const Color(0xFFFFC857);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF17233C),
            Color.alphaBlend(accent.withValues(alpha: 0.12), const Color(0xFF101A2D)),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(service.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 4),
                    Text(
                      service.image,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                    ),
                  ],
                ),
              ),
              if (mountRoot != null && mountRoot!.trim().isNotEmpty) ...[
                IconButton(
                  tooltip: 'Open data folder',
                  onPressed: () => _openDirectory(context, mountRoot!),
                  icon: const Icon(Icons.folder_open_rounded),
                ),
                const SizedBox(width: 4),
              ],
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(color: accent.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                child: Text(_isRunning ? 'RUNNING' : 'STOPPED', style: theme.textTheme.labelSmall?.copyWith(color: accent, fontWeight: FontWeight.w800, letterSpacing: 1)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionChip(
                label: service.localUrl.trim().isNotEmpty ? 'Open' : 'Manage',
                icon: service.localUrl.trim().isNotEmpty ? Icons.open_in_new_rounded : Icons.tune_rounded,
                onTap: () {
                  if (service.localUrl.trim().isNotEmpty) {
                    _openUrl(context, service.localUrl);
                  }
                },
              ),
              _ActionChip(label: 'Details', icon: Icons.tune_rounded, onTap: () => showServiceDetailsSheet(context, service)),
              _ActionChip(
                label: _isRunning ? 'Pause' : 'Start',
                icon: _isRunning ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                onTap: () => bloc.add(_isRunning ? MainStopRequested(id: service.id) : MainStartRequested(id: service.id)),
              ),
              _ActionChip(label: 'Restart', icon: Icons.restart_alt_rounded, onTap: () => bloc.add(MainRestartRequested(id: service.id))),
              _ActionChip(
                label: service.lanEnabled ? 'LAN On' : 'LAN Off',
                icon: Icons.wifi_tethering_rounded,
                onTap: () => bloc.add(MainExposeLanRequested(id: service.id, enabled: !service.lanEnabled)),
              ),
              _ActionChip(label: 'Remove', icon: Icons.delete_outline_rounded, destructive: true, onTap: () => _confirmRemove(context, bloc)),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 4),
          if (liveMetrics != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _ServiceMeta(label: 'CPU', value: '${liveMetrics!.cpuPercent.toStringAsFixed(1)}%'),
                _ServiceMeta(
                  label: 'RAM',
                  value: liveMetrics!.memoryLimitBytes > 0
                      ? '${_formatBytes(liveMetrics!.memoryUsageBytes)} / ${_formatBytes(liveMetrics!.memoryLimitBytes)}'
                      : _formatBytes(liveMetrics!.memoryUsageBytes),
                ),
                _ServiceMeta(label: 'Net', value: '${_formatBytes(liveMetrics!.networkRxBytes)} rx / ${_formatBytes(liveMetrics!.networkTxBytes)} tx'),
                _ServiceMeta(label: 'Data', value: _formatBytes(storageBytes ?? 0)),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              _ServiceMeta(label: 'Port', value: service.port > 0 ? '${service.port}' : 'none'),
              const SizedBox(width: 16),
              Expanded(child: _ServiceMeta(label: 'Status', value: service.status)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, MainBloc bloc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove service?'),
        content: Text('This will remove "${service.name}" from the current deployment.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      bloc.add(MainRemoveRequested(id: service.id));
    }
  }
}

class _InactiveServiceTile extends StatelessWidget {
  const _InactiveServiceTile({required this.definition});

  final GoServiceDefinition definition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<MainBloc>();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(definition.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFC857).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                child: Text('SAVED', style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFFFFC857), fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(definition.image, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.66))),
          const Spacer(),
          Row(
            children: [
              Expanded(child: _CompactActionChip(label: 'Restore', icon: Icons.restore_rounded, color: const Color(0xFF80ED99), onTap: () => bloc.add(MainRecreateRequested(id: definition.id)))),
              const SizedBox(width: 6),
              Expanded(child: _CompactActionChip(label: 'Delete', icon: Icons.delete_outline_rounded, color: const Color(0xFFFF7B72), onTap: () => _confirmDelete(context, bloc))),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MainBloc bloc) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved service?'),
        content: Text(
          'Choose whether to remove only the saved definition for "${definition.name}" or also delete its managed persistent data.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          OutlinedButton(
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
    if (choice != null && context.mounted) {
      bloc.add(
        MainDeleteDefinitionRequested(
          id: definition.id,
          deleteData: choice == 'definition+data',
        ),
      );
    }
  }
}

class _DataPanel extends StatelessWidget {
  const _DataPanel({
    required this.dataEntries,
    required this.onChanged,
  });

  final List<_DataEntry> dataEntries;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Data', style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 2),
          Text(
            'Persistent folders managed by Serva. These can be reopened and potentially rebound later.',
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              final crossAxisCount = width >= 1400 ? 4 : width >= 1000 ? 3 : width >= 700 ? 2 : 1;
              return GridView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: dataEntries.length,
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossAxisCount,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                  childAspectRatio: crossAxisCount == 1 ? 3.2 : crossAxisCount >= 3 ? 1.75 : 2.2,
                ),
                itemBuilder: (context, index) => _DataTile(
                  entry: dataEntries[index],
                  onChanged: onChanged,
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({required this.label, required this.icon, required this.onTap, this.destructive = false});

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = destructive ? const Color(0xFFFF7B72) : theme.colorScheme.primary;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 15, color: color),
              const SizedBox(width: 4),
              Text(label, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DataTile extends StatelessWidget {
  const _DataTile({
    required this.entry,
    required this.onChanged,
  });

  final _DataEntry entry;
  final VoidCallback onChanged;

  String? get _miscRoot {
    for (final mount in entry.mounts) {
      if (mount.type.trim().toLowerCase() == 'bind' && mount.target.trim() == '/misc') {
        final source = mount.source.trim();
        if (source.isNotEmpty) {
          return source;
        }
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<MainBloc>();
    final statusColor = entry.isGlobalRoot
        ? const Color(0xFF4CC9F0)
        : entry.isOrphaned
        ? const Color(0xFFFF7B72)
        : entry.isDeployed
            ? const Color(0xFF80ED99)
            : const Color(0xFFFFC857);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder_open_rounded, color: statusColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.serviceName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      entry.image,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ServiceMeta(
            label: 'Status',
            value: entry.isGlobalRoot
                ? 'Serva local'
                : entry.isOrphaned
                ? 'Orphaned data'
                : entry.isDeployed
                    ? 'Connected'
                    : 'Saved only',
          ),
          const SizedBox(height: 8),
          _ServiceMeta(label: 'Size', value: _formatBytes(entry.sizeBytes)),
          const SizedBox(height: 8),
          _ServiceMeta(label: 'Root folder', value: entry.rootPath),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...entry.mounts.map(
                (mount) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    mount.target,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
              ...entry.miscSubfolders.map(
                (folder) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                  decoration: BoxDecoration(
                    color: const Color(0xFF4CC9F0).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                    border: Border.all(color: const Color(0xFF4CC9F0).withValues(alpha: 0.18)),
                  ),
                  child: Text(
                    folder,
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: const Color(0xFF9EDFF5),
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          if (_miscRoot != null) ...[
            Row(
              children: [
                Expanded(
                child: _CompactActionChip(
                    label: 'New folder',
                    icon: Icons.create_new_folder_rounded,
                    color: const Color(0xFF80ED99),
                    onTap: () => _createMiscSubfolder(context, bloc, _miscRoot!),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                child: _CompactActionChip(
                    label: 'Delete folder',
                    icon: Icons.folder_delete_rounded,
                    color: const Color(0xFFFFC857),
                    onTap: () => _deleteMiscSubfolder(context, bloc, _miscRoot!),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Row(
            children: [
              Expanded(
                child: _CompactActionChip(
                  label: 'Open folder',
                  icon: Icons.folder_open_rounded,
                  color: const Color(0xFF4CC9F0),
                  onTap: () => _openDirectory(context, entry.rootPath),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactActionChip(
                  label: 'Wipe',
                  icon: Icons.cleaning_services_rounded,
                  color: const Color(0xFFFFC857),
                  onTap: () => _confirmWipe(context, bloc),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactActionChip(
                  label: 'Delete',
                  icon: Icons.delete_forever_rounded,
                  color: const Color(0xFFFF7B72),
                  onTap: () => _confirmDelete(context, bloc),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmWipe(BuildContext context, MainBloc bloc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wipe data contents?'),
        content: Text(
          entry.isDeployed
              ? 'This will delete everything inside "${entry.rootPath}" while keeping the folder itself. The connected service may break until it recreates its data.'
              : 'This will delete everything inside "${entry.rootPath}" while keeping the folder itself.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Wipe data'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final root = Directory(entry.rootPath);
      if (root.existsSync()) {
        _wipeDirectoryContents(root);
      } else {
        root.createSync(recursive: true);
      }

      if (entry.isGlobalRoot) {
        TemplateGalleryScreen.resetLocalTemplateState();
      }

      onChanged();
      final liveServiceId = _liveServiceIdForEntry(bloc);
      if (liveServiceId != null) {
        bloc.add(MainRestartRequested(id: liveServiceId));
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              liveServiceId != null
                  ? 'Wiped data and restarted ${entry.serviceName}.'
                  : 'Wiped data in ${entry.rootPath}.',
            ),
          ),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not wipe data: $error')),
      );
    }
  }

  Future<void> _createMiscSubfolder(
    BuildContext context,
    MainBloc bloc,
    String miscRoot,
  ) async {
    final controller = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create misc folder'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: const InputDecoration(
            labelText: 'Folder name',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text.trim()),
            child: const Text('Create'),
          ),
        ],
      ),
    );
    controller.dispose();

    if (folderName == null || folderName.isEmpty || !context.mounted) return;
    if (folderName.contains('\\') || folderName.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Folder name cannot contain slashes.')),
      );
      return;
    }

    try {
      final folder = Directory('$miscRoot${Platform.pathSeparator}$folderName');
      folder.createSync(recursive: true);
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Created misc folder $folderName')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not create misc folder: $error')),
      );
    }
  }

  Future<void> _deleteMiscSubfolder(
    BuildContext context,
    MainBloc bloc,
    String miscRoot,
  ) async {
    final root = Directory(miscRoot);
    final folders = root.existsSync()
        ? (root
              .listSync(followLinks: false)
              .whereType<Directory>()
              .map((directory) => directory.path)
              .toList()
          ..sort())
        : <String>[];

    if (folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No misc subfolders to delete.')),
      );
      return;
    }

    String? selected = folders.first;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete misc folder'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return DropdownButtonFormField<String>(
              value: selected,
              decoration: const InputDecoration(
                labelText: 'Folder',
                border: OutlineInputBorder(),
              ),
              items: folders
                  .map(
                    (path) => DropdownMenuItem<String>(
                      value: path,
                      child: Text(_folderLeafName(path)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                setDialogState(() {
                  selected = value;
                });
              },
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(selected),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    try {
      final directory = Directory(choice);
      if (directory.existsSync()) {
        directory.deleteSync(recursive: true);
      }

      if (entry.isGlobalRoot) {
        TemplateGalleryScreen.resetLocalTemplateState();
      }
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Deleted misc folder ${_folderLeafName(choice)}')),
      );
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete misc folder: $error')),
      );
    }
  }

  String? _liveServiceIdForEntry(MainBloc bloc) {
    final state = bloc.state;
    if (state is! MainLoaded) return null;

    for (final service in state.services) {
      if (service.name == entry.serviceName) {
        return service.id;
      }
    }
    return null;
  }

  void _wipeDirectoryContents(Directory directory) {
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is File) {
        entity.deleteSync();
        continue;
      }

      if (entity is Link) {
        entity.deleteSync();
        continue;
      }

      if (entity is Directory) {
        _wipeDirectoryContents(entity);
      }
    }
  }

  Future<void> _confirmDelete(BuildContext context, MainBloc bloc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete data folder?'),
        content: Text(
          entry.isDeployed
              ? 'This will permanently delete "${entry.rootPath}" and all of its contents. The connected service may stop working until a new data folder is attached.'
              : 'This will permanently delete "${entry.rootPath}" and all of its contents.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete folder'),
          ),
        ],
      ),
    );

    if (confirmed != true || !context.mounted) return;

    try {
      final root = Directory(entry.rootPath);
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }

      if (entry.isGlobalRoot) {
        TemplateGalleryScreen.resetLocalTemplateState();
      }

      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Deleted data folder ${entry.rootPath}')),
        );
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not delete data folder: $error')),
      );
    }
  }
}

class _CompactActionChip extends StatelessWidget {
  const _CompactActionChip({required this.label, required this.icon, required this.color, required this.onTap});

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: color.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 4),
              Flexible(child: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.labelMedium?.copyWith(color: color, fontWeight: FontWeight.w700))),
            ],
          ),
        ),
      ),
    );
  }
}

class _ServiceMeta extends StatelessWidget {
  const _ServiceMeta({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.58), letterSpacing: 1)),
        const SizedBox(height: 3),
        Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
      ],
    );
  }
}

class _ServicesMetrics {
  const _ServicesMetrics({
    required this.liveMetrics,
    required this.serviceStorageBytes,
    required this.serviceMountRoots,
    required this.dataEntries,
  });

  final Map<String, _ServiceLiveMetrics> liveMetrics;
  final Map<String, double> serviceStorageBytes;
  final Map<String, String> serviceMountRoots;
  final List<_DataEntry> dataEntries;
}

class _DataEntry {
  const _DataEntry({
    required this.serviceId,
    required this.serviceName,
    required this.image,
    required this.rootPath,
    required this.isDeployed,
    required this.mounts,
    required this.isOrphaned,
    required this.isGlobalRoot,
    this.sizeBytes = 0,
    this.miscSubfolders = const [],
  });

  final String serviceId;
  final String serviceName;
  final String image;
  final String rootPath;
  final bool isDeployed;
  final List<GoServiceDefinitionMount> mounts;
  final bool isOrphaned;
  final bool isGlobalRoot;
  final double sizeBytes;
  final List<String> miscSubfolders;

  _DataEntry copyWith({
    String? serviceId,
    String? serviceName,
    String? image,
    String? rootPath,
    bool? isDeployed,
    List<GoServiceDefinitionMount>? mounts,
    bool? isOrphaned,
    bool? isGlobalRoot,
    double? sizeBytes,
    List<String>? miscSubfolders,
  }) {
    return _DataEntry(
      serviceId: serviceId ?? this.serviceId,
      serviceName: serviceName ?? this.serviceName,
      image: image ?? this.image,
      rootPath: rootPath ?? this.rootPath,
      isDeployed: isDeployed ?? this.isDeployed,
      mounts: mounts ?? this.mounts,
      isOrphaned: isOrphaned ?? this.isOrphaned,
      isGlobalRoot: isGlobalRoot ?? this.isGlobalRoot,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      miscSubfolders: miscSubfolders ?? this.miscSubfolders,
    );
  }
}

class _ServiceLiveMetrics {
  const _ServiceLiveMetrics({
    required this.cpuPercent,
    required this.memoryUsageBytes,
    required this.memoryLimitBytes,
    required this.networkRxBytes,
    required this.networkTxBytes,
  });

  final double cpuPercent;
  final double memoryUsageBytes;
  final double memoryLimitBytes;
  final double networkRxBytes;
  final double networkTxBytes;
}

double _cpuPercentFromStats(Map<String, dynamic> raw) {
  final cpuStats = _mapValue(raw['cpu_stats']);
  final precpuStats = _mapValue(raw['precpu_stats']);
  final cpuUsage = _mapValue(cpuStats['cpu_usage']);
  final precpuUsage = _mapValue(precpuStats['cpu_usage']);
  final currentTotal = _asDouble(cpuUsage['total_usage']);
  final previousTotal = _asDouble(precpuUsage['total_usage']);
  final currentSystem = _asDouble(cpuStats['system_cpu_usage']);
  final previousSystem = _asDouble(precpuStats['system_cpu_usage']);
  final cpuDelta = currentTotal - previousTotal;
  final systemDelta = currentSystem - previousSystem;
  final onlineCpus = _asDouble(cpuStats['online_cpus']);
  final cores = onlineCpus > 0 ? onlineCpus : (_listValue(cpuUsage['percpu_usage']).isNotEmpty ? _listValue(cpuUsage['percpu_usage']).length.toDouble() : 1);
  if (cpuDelta <= 0 || systemDelta <= 0) return 0;
  return (cpuDelta / systemDelta) * cores * 100;
}

double _memoryUsageBytesFromStats(Map<String, dynamic> raw) => _asDouble(_mapValue(raw['memory_stats'])['usage']);
double _memoryLimitBytesFromStats(Map<String, dynamic> raw) => _asDouble(_mapValue(raw['memory_stats'])['limit']);

double _networkRxBytesFromStats(Map<String, dynamic> raw) {
  final networks = _mapValue(raw['networks']);
  var total = 0.0;
  for (final value in networks.values) {
    total += _asDouble(_mapValue(value)['rx_bytes']);
  }
  return total;
}

double _networkTxBytesFromStats(Map<String, dynamic> raw) {
  final networks = _mapValue(raw['networks']);
  var total = 0.0;
  for (final value in networks.values) {
    total += _asDouble(_mapValue(value)['tx_bytes']);
  }
  return total;
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) return value.map((key, item) => MapEntry(key.toString(), item));
  return const {};
}

List<dynamic> _listValue(dynamic value) => value is List ? value : const [];

double _asDouble(dynamic value) {
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0;
  return 0;
}

String _formatBytes(double bytes) {
  if (bytes <= 0) return '0 B';
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes;
  var unitIndex = 0;
  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }
  final precision = value >= 100 ? 0 : value >= 10 ? 1 : 2;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}

String _servaManagedBasePath() {
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

String _servaLocalDataPath() {
  return '${_servaManagedBasePath()}${Platform.pathSeparator}serva-local';
}

String? _serviceMountRootFromDefinition(GoServiceDefinition definition) {
  if (definition.mounts.isEmpty) return null;
  final first = definition.mounts.first.source.trim();
  if (first.isEmpty) return null;
  return Directory(first).parent.path;
}

String? _dataRootFromDefinition(GoServiceDefinition definition) {
  final managedBindMounts = definition.mounts
      .where((mount) => mount.managed && mount.type.trim().toLowerCase() == 'bind')
      .toList();
  if (managedBindMounts.isEmpty) return null;

  final first = managedBindMounts.first.source.trim();
  if (first.isEmpty) return null;

  return Directory(first).parent.path;
}

String _psEscape(String value) => value.replaceAll("'", "''");

String _folderLeafName(String path) {
  final normalized = path.replaceAll('/', '\\');
  final segments = normalized.split('\\').where((segment) => segment.trim().isNotEmpty).toList();
  return segments.isEmpty ? path : segments.last;
}

Future<void> _openUrl(BuildContext context, String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return;

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open service link')),
    );
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
