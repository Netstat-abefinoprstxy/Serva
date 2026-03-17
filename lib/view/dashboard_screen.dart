import 'dart:math';
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

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, required this.state});

  final MainLoaded state;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final ServaApi _api = ServaApi();
  late Future<_DashboardMetrics> _metricsFuture;
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _loadMetrics();
    _refreshTimer = Timer.periodic(const Duration(seconds: 12), (_) {
      if (!mounted) return;
      setState(() {
        _metricsFuture = _loadMetrics();
      });
    });
  }

  @override
  void didUpdateWidget(covariant DashboardScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.state.services != widget.state.services ||
        oldWidget.state.definitions != widget.state.definitions ||
        oldWidget.state.healthOk != widget.state.healthOk) {
      _metricsFuture = _loadMetrics();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<_DashboardMetrics> _loadMetrics() async {
    final services = widget.state.services;
    final serviceStats = await Future.wait(
      services.map((service) async {
        try {
          return await _api.serviceStats(service.id);
        } catch (_) {
          return null;
        }
      }),
    );

    final usableStats = serviceStats.whereType<GoStatsResponse>().toList();
    final hostMetrics = await _loadHostMetrics();

    final containerCpu = usableStats.fold<double>(0, (sum, stat) => sum + _cpuPercentFromStats(stat.raw));
    final containerMemoryBytes = usableStats.fold<double>(
      0,
      (sum, stat) => sum + _memoryUsageBytesFromStats(stat.raw),
    );
    final containerNetworkBytes = usableStats.fold<double>(
      0,
      (sum, stat) => sum + _networkBytesFromStats(stat.raw),
    );

    return _DashboardMetrics(
      hostCpuPercent: hostMetrics.cpuPercent,
      hostMemoryPercent: hostMetrics.memoryPercent,
      hostStoragePercent: hostMetrics.storagePercent,
      containerCpuPercent: containerCpu,
      containerMemoryBytes: containerMemoryBytes,
      containerNetworkBytes: containerNetworkBytes,
      liveStatsCount: usableStats.length,
      cpuSeries: _buildSeriesFromSeed(hostMetrics.cpuPercent.round(), 18, 14),
      memorySeries: _buildSeriesFromSeed(hostMetrics.memoryPercent.round(), 15, 10),
      networkSeries: _buildSeriesFromSeed((_bytesToMegabytes(containerNetworkBytes)).round(), 20, 18),
      storageSeries: _buildSeriesFromSeed(hostMetrics.storagePercent.round(), 12, 7),
    );
  }

  Future<_HostMetrics> _loadHostMetrics() async {
    if (!Platform.isWindows) {
      return const _HostMetrics(cpuPercent: 0, memoryPercent: 0, storagePercent: 0);
    }

    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final documentsPath = userProfile.isNotEmpty ? '$userProfile\\Documents\\Serva' : 'C:\\';
      final drive = documentsPath.length >= 2 ? documentsPath.substring(0, 2) : 'C:';
      final command = r'''
$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$os = Get-CimInstance Win32_OperatingSystem
$totalMemory = [double]$os.TotalVisibleMemorySize
$freeMemory = [double]$os.FreePhysicalMemory
$memoryPercent = if ($totalMemory -gt 0) { (($totalMemory - $freeMemory) / $totalMemory) * 100 } else { 0 }
$drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='__DRIVE__'"
$storagePercent = if ($drive -and [double]$drive.Size -gt 0) { (([double]$drive.Size - [double]$drive.FreeSpace) / [double]$drive.Size) * 100 } else { 0 }
@{
  cpu = [math]::Round($cpu, 1)
  memory = [math]::Round($memoryPercent, 1)
  storage = [math]::Round($storagePercent, 1)
} | ConvertTo-Json -Compress
'''.replaceAll('__DRIVE__', drive);

      final result = await Process.run(
        'powershell',
        ['-NoProfile', '-Command', command],
      );

      if (result.exitCode != 0) {
        return const _HostMetrics(cpuPercent: 0, memoryPercent: 0, storagePercent: 0);
      }

      final raw = result.stdout.toString().trim();
      if (raw.isEmpty) {
        return const _HostMetrics(cpuPercent: 0, memoryPercent: 0, storagePercent: 0);
      }

      final json = jsonDecode(raw);
      if (json is! Map) {
        return const _HostMetrics(cpuPercent: 0, memoryPercent: 0, storagePercent: 0);
      }

      return _HostMetrics(
        cpuPercent: _asDouble(json['cpu']),
        memoryPercent: _asDouble(json['memory']),
        storagePercent: _asDouble(json['storage']),
      );
    } catch (_) {
      return const _HostMetrics(cpuPercent: 0, memoryPercent: 0, storagePercent: 0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final services = widget.state.services;
    final definitions = widget.state.definitions;
    final runningServices = services.where((service) => service.state.toLowerCase() == 'running').length;
    final lanServices = services.where((service) => service.lanEnabled).length;
    final savedOnlyDefinitions = definitions.where((definition) => !definition.isDeployed).length;

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF08111F),
            Color(0xFF101B31),
            Color(0xFF171E2D),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(8),
        children: [
          Text(
            'System Command',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'A quick, high-confidence read on your local stack.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
            ),
          ),
          const SizedBox(height: 8),
          _ServiceControlPanel(services: services),
          if (savedOnlyDefinitions > 0) ...[
            const SizedBox(height: 8),
            _InactiveServicePanel(
              definitions: definitions.where((definition) => !definition.isDeployed).toList(),
            ),
          ],
          const SizedBox(height: 8),
          _HeroPanel(
            healthOk: widget.state.healthOk,
            runningServices: runningServices,
            totalServices: services.length,
            savedDefinitions: savedOnlyDefinitions,
            lanServices: lanServices,
            throughputSeries: _buildSeriesFromSeed(services.length * 17 + 11, 18, 18),
          ),
          const SizedBox(height: 8),
          FutureBuilder<_DashboardMetrics>(
            future: _metricsFuture,
            builder: (context, snapshot) {
              final metrics = snapshot.data;
              final cpuUsage = _boundedValue((metrics?.hostCpuPercent ?? 0).round(), 0, 100);
              final memoryUsage = _boundedValue((metrics?.hostMemoryPercent ?? 0).round(), 0, 100);
              final storageUsage = _boundedValue((metrics?.hostStoragePercent ?? 0).round(), 0, 100);
              final containerCpu = _boundedValue((metrics?.containerCpuPercent ?? 0).round(), 0, 999);
              final networkMegabytes = _bytesToMegabytes(metrics?.containerNetworkBytes ?? 0);
              final containerMemoryMegabytes = _bytesToMegabytes(metrics?.containerMemoryBytes ?? 0);
              final liveStatsCount = metrics?.liveStatsCount ?? 0;

              final width = MediaQuery.of(context).size.width;
              final crossAxisCount = width >= 1400
                  ? 4
                  : width >= 1000
                  ? 4
                  : 2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                shrinkWrap: true,
                childAspectRatio: crossAxisCount >= 4 ? 1.72 : 1.95,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                    label: 'Host CPU',
                    value: '$cpuUsage%',
                    caption: 'Real Windows CPU load',
                    color: const Color(0xFF4CC9F0),
                    icon: Icons.memory_rounded,
                    series: metrics?.cpuSeries ?? _buildSeriesFromSeed(cpuUsage, 18, 10),
                  ),
                  _StatCard(
                    label: 'Host Memory',
                    value: '$memoryUsage%',
                    caption: 'Physical memory in use',
                    color: const Color(0xFF80ED99),
                    icon: Icons.stacked_line_chart_rounded,
                    series: metrics?.memorySeries ?? _buildSeriesFromSeed(memoryUsage, 18, 10),
                  ),
                  _StatCard(
                    label: 'Containers',
                    value: '${containerCpu.toString()}%',
                    caption: liveStatsCount == 0
                        ? 'No live Docker stats yet'
                        : '${containerMemoryMegabytes.toStringAsFixed(1)} MB memory in live services',
                    color: const Color(0xFFFFC857),
                    icon: Icons.wifi_tethering_rounded,
                    series: metrics?.networkSeries ??
                        _buildSeriesFromSeed(networkMegabytes.round(), 18, 16),
                    footer: liveStatsCount == 0
                        ? 'Waiting for container stats'
                        : '${networkMegabytes.toStringAsFixed(1)} MB network I/O observed',
                  ),
                  _StatCard(
                    label: 'Host Storage',
                    value: '$storageUsage%',
                    caption: 'Disk usage on the Serva drive',
                    color: const Color(0xFFFF7B72),
                    icon: Icons.storage_rounded,
                    series: metrics?.storageSeries ?? _buildSeriesFromSeed(storageUsage, 18, 8),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              if (narrow) {
                return Column(
                  children: [
                    _ActivityPanel(
                      services: services.map((service) => _ServicePulse.fromService(service)).toList(),
                    ),
                    const SizedBox(height: 8),
                    _MissionPanel(
                      healthOk: widget.state.healthOk,
                      savedDefinitions: savedOnlyDefinitions,
                      services: services.length,
                    ),
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 3,
                    child: _ActivityPanel(
                      services: services.map((service) => _ServicePulse.fromService(service)).toList(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: _MissionPanel(
                      healthOk: widget.state.healthOk,
                      savedDefinitions: savedOnlyDefinitions,
                      services: services.length,
                    ),
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  static int _boundedValue(int value, int min, int max) {
    return value.clamp(min, max);
  }

  static List<double> _buildSeriesFromSeed(int seed, int points, int amplitude) {
    final random = Random(seed);
    return List<double>.generate(
      points,
      (index) {
        final base = 42 + sin((index + seed) / 2.2) * amplitude;
        final noise = random.nextDouble() * 12 - 6;
        return (base + noise).clamp(8, 96).toDouble();
      },
    );
  }
}

class _ServiceControlPanel extends StatelessWidget {
  const _ServiceControlPanel({required this.services});

  final List<GoService> services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Active services',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 1),
          Text(
            'Start, pause, restart, remove, and open your current services without leaving the dashboard.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 8),
          if (services.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text('No running or saved containers are active yet. Launch one from the Launch tab.'),
            )
          else
            LayoutBuilder(
              builder: (context, constraints) {
                final width = constraints.maxWidth;
                final crossAxisCount = width >= 1320
                    ? 5
                    : width >= 1150
                    ? 4
                    : width >= 900
                    ? 3
                    : width >= 680
                    ? 2
                    : 1;

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
                    return _ServiceCommandTile(service: services[index]);
                  },
                );
              },
            ),
        ],
      ),
    );
  }
}

class _InactiveServicePanel extends StatelessWidget {
  const _InactiveServicePanel({required this.definitions});

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
          Text(
            'Inactive services',
            style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
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
              final crossAxisCount = width >= 1500
                  ? 6
                  : width >= 1200
                  ? 5
                  : width >= 900
                  ? 4
                  : width >= 650
                  ? 3
                  : width >= 440
                  ? 2
                  : 1;

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
                itemBuilder: (context, index) {
                  return _InactiveServiceTile(definition: definitions[index]);
                },
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ServiceCommandTile extends StatelessWidget {
  const _ServiceCommandTile({required this.service});

  final GoService service;

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
                    Text(
                      service.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.image,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isRunning ? 'RUNNING' : 'STOPPED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
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
              _ActionChip(
                label: _isRunning ? 'Pause' : 'Start',
                icon: _isRunning ? Icons.pause_circle_outline_rounded : Icons.play_circle_outline_rounded,
                onTap: () {
                  if (_isRunning) {
                    bloc.add(MainStopRequested(id: service.id));
                  } else {
                    bloc.add(MainStartRequested(id: service.id));
                  }
                },
              ),
              _ActionChip(
                label: 'Restart',
                icon: Icons.restart_alt_rounded,
                onTap: () => bloc.add(MainRestartRequested(id: service.id)),
              ),
              _ActionChip(
                label: service.lanEnabled ? 'LAN On' : 'LAN Off',
                icon: Icons.wifi_tethering_rounded,
                onTap: () => bloc.add(MainExposeLanRequested(id: service.id, enabled: !service.lanEnabled)),
              ),
              _ActionChip(
                label: 'Remove',
                icon: Icons.delete_outline_rounded,
                destructive: true,
                onTap: () => _confirmRemove(context, bloc),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 4),
          Row(
            children: [
              _ServiceMeta(label: 'Port', value: service.port > 0 ? '${service.port}' : 'none'),
              const SizedBox(width: 16),
              Expanded(
                child: _ServiceMeta(label: 'Status', value: service.status),
              ),
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
              Expanded(
                child: Text(
                  definition.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFC857).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  'SAVED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: const Color(0xFFFFC857),
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            definition.image,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
            ),
          ),
          const Spacer(),
          Row(
            children: [
              Expanded(
                child: _CompactActionChip(
                  label: 'Restore',
                  icon: Icons.restore_rounded,
                  color: const Color(0xFF80ED99),
                  onTap: () => bloc.add(MainRecreateRequested(id: definition.id)),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: _CompactActionChip(
                  label: 'Delete',
                  icon: Icons.delete_outline_rounded,
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

  Future<void> _confirmDelete(BuildContext context, MainBloc bloc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved service?'),
        content: Text('Delete the saved definition for "${definition.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      bloc.add(MainDeleteDefinitionRequested(id: definition.id));
    }
  }
}

class _ActionChip extends StatelessWidget {
  const _ActionChip({
    required this.label,
    required this.icon,
    required this.onTap,
    this.destructive = false,
  });

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
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CompactActionChip extends StatelessWidget {
  const _CompactActionChip({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

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
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
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
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.healthOk,
    required this.runningServices,
    required this.totalServices,
    required this.savedDefinitions,
    required this.lanServices,
    required this.throughputSeries,
  });

  final bool healthOk;
  final int runningServices;
  final int totalServices;
  final int savedDefinitions;
  final int lanServices;
  final List<double> throughputSeries;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF101D36),
            Color(0xFF0D1527),
          ],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: healthOk ? const Color(0xFF80ED99) : const Color(0xFFFF7B72),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (healthOk ? const Color(0xFF80ED99) : const Color(0xFFFF7B72))
                          .withValues(alpha: 0.45),
                      blurRadius: 18,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Text(
                healthOk ? 'System stable' : 'Attention needed',
                style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            healthOk
                ? 'Your local platform is online and ready to orchestrate services.'
                : 'The control layer is having trouble reaching Docker or the backend.',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.8),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 850;
              if (compact) {
                return Column(
                  children: [
                    _MiniStatStrip(
                      label: 'Running',
                      value: '$runningServices',
                      accent: const Color(0xFF4CC9F0),
                    ),
                    const SizedBox(height: 4),
                    _MiniStatStrip(
                      label: 'Tracked',
                      value: '$totalServices',
                      accent: const Color(0xFF80ED99),
                    ),
                    const SizedBox(height: 4),
                    _MiniStatStrip(
                      label: 'Saved',
                      value: '$savedDefinitions',
                      accent: const Color(0xFFFFC857),
                    ),
                    const SizedBox(height: 4),
                    _MiniStatStrip(
                      label: 'LAN',
                      value: '$lanServices',
                      accent: const Color(0xFFFF7B72),
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'Running',
                      value: '$runningServices',
                      accent: const Color(0xFF4CC9F0),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'Tracked',
                      value: '$totalServices',
                      accent: const Color(0xFF80ED99),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'Saved',
                      value: '$savedDefinitions',
                      accent: const Color(0xFFFFC857),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'LAN',
                      value: '$lanServices',
                      accent: const Color(0xFFFF7B72),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 68,
            child: CustomPaint(
              painter: _AreaChartPainter(
                values: throughputSeries,
                color: const Color(0xFF4CC9F0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
    required this.series,
    this.footer,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;
  final List<double> series;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1728).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, color: color),
              ),
              const Spacer(),
              Text(
                label.toUpperCase(),
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                  letterSpacing: 1.1,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            value,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            caption,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (footer != null) ...[
            const SizedBox(height: 2),
            Text(
              footer!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
              ),
            ),
          ],
          const SizedBox(height: 4),
          SizedBox(
            height: 18,
            child: CustomPaint(
              painter: _LineChartPainter(values: series, color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.services});

  final List<_ServicePulse> services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live activity',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 1),
          Text(
            'A stylized pulse view of the services Serva is tracking right now.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          const SizedBox(height: 6),
          if (services.isEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(18),
              ),
              child: const Text('No live services yet. Create one and this dashboard will light up.'),
            )
          else
            for (var i = 0; i < services.length; i++) ...[
              _ActivityRow(service: services[i]),
              if (i != services.length - 1) const SizedBox(height: 6),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.service});

  final _ServicePulse service;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = service.running ? const Color(0xFF80ED99) : const Color(0xFFFF7B72);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  service.name,
                  style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  service.running ? 'RUNNING' : 'IDLE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          SizedBox(
            height: 20,
            child: CustomPaint(
              painter: _LineChartPainter(values: service.series, color: accent),
            ),
          ),
          const SizedBox(height: 3),
          Row(
            children: [
              _InlineMetric(label: 'Port', value: service.portLabel),
              const SizedBox(width: 8),
              _InlineMetric(label: 'Mode', value: service.lanEnabled ? 'LAN' : 'Local'),
              const SizedBox(width: 8),
              Expanded(child: _InlineMetric(label: 'Image', value: service.image)),
            ],
          ),
        ],
      ),
    );
  }
}

class _MissionPanel extends StatelessWidget {
  const _MissionPanel({
    required this.healthOk,
    required this.savedDefinitions,
    required this.services,
  });

  final bool healthOk;
  final int savedDefinitions;
  final int services;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final readiness = (healthOk ? 44 : 18) + (services * 9) + (savedDefinitions * 4);
    final readinessScore = readiness.clamp(0, 100);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mission profile',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Center(
            child: SizedBox(
              width: 112,
              height: 112,
              child: CustomPaint(
                painter: _GaugePainter(value: readinessScore / 100),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$readinessScore%',
                        style: theme.textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Readiness',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          _ChecklistItem(
            title: healthOk ? 'Control plane reachable' : 'Control plane degraded',
            subtitle: healthOk ? 'Serva can talk to the local daemon.' : 'Backend or Docker needs attention.',
            success: healthOk,
          ),
          const SizedBox(height: 4),
          _ChecklistItem(
            title: '$services services under management',
            subtitle: 'Live containers are currently reflected in the command center.',
            success: services > 0,
          ),
          const SizedBox(height: 4),
          _ChecklistItem(
            title: '$savedDefinitions saved definitions',
            subtitle: 'Recreation metadata is available for durability workflows.',
            success: savedDefinitions > 0,
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.title,
    required this.subtitle,
    required this.success,
  });

  final String title;
  final String subtitle;
  final bool success;

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF80ED99) : const Color(0xFFFFC857);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Icon(
            success ? Icons.verified_rounded : Icons.timelapse_rounded,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.titleSmall),
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStatStrip extends StatelessWidget {
  const _MiniStatStrip({
    required this.label,
    required this.value,
    required this.accent,
  });

  final String label;
  final String value;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(label)),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}

class _LineChartPainter extends CustomPainter {
  _LineChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 2.4
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final glowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 9
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / 100) * size.height);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    canvas.drawPath(path, glowPaint);
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _AreaChartPainter extends CustomPainter {
  _AreaChartPainter({required this.values, required this.color});

  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;

    final linePath = Path();
    for (var i = 0; i < values.length; i++) {
      final x = (i / (values.length - 1)) * size.width;
      final y = size.height - ((values[i] / 100) * size.height);
      if (i == 0) {
        linePath.moveTo(x, y);
      } else {
        linePath.lineTo(x, y);
      }
    }

    final fillPath = Path.from(linePath)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          color.withValues(alpha: 0.35),
          color.withValues(alpha: 0.02),
        ],
      ).createShader(Offset.zero & size);

    final linePaint = Paint()
      ..color = color
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(linePath, linePaint);
  }

  @override
  bool shouldRepaint(covariant _AreaChartPainter oldDelegate) {
    return oldDelegate.values != values || oldDelegate.color != color;
  }
}

class _GaugePainter extends CustomPainter {
  _GaugePainter({required this.value});

  final double value;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = min(size.width, size.height) / 2 - 12;

    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.07)
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    final progressPaint = Paint()
      ..shader = const SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [
          Color(0xFF4CC9F0),
          Color(0xFF80ED99),
          Color(0xFFFFC857),
        ],
      ).createShader(Rect.fromCircle(center: center, radius: radius))
      ..strokeWidth = 14
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, basePaint);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      -pi / 2,
      2 * pi * value.clamp(0.0, 1.0),
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GaugePainter oldDelegate) {
    return oldDelegate.value != value;
  }
}

class _ServicePulse {
  const _ServicePulse({
    required this.name,
    required this.image,
    required this.running,
    required this.lanEnabled,
    required this.portLabel,
    required this.series,
  });

  final String name;
  final String image;
  final bool running;
  final bool lanEnabled;
  final String portLabel;
  final List<double> series;

  factory _ServicePulse.fromService(GoService service) {
    final running = service.state.toLowerCase() == 'running';
    final seed = service.name.codeUnits.fold<int>(0, (sum, item) => sum + item);
    final random = Random(seed);
    final base = running ? 62.0 : 22.0;
    final series = List<double>.generate(
      16,
      (index) => (base + sin((index + seed) / 2) * 14 + (random.nextDouble() * 9 - 4))
          .clamp(5, 96)
          .toDouble(),
    );

    return _ServicePulse(
      name: service.name,
      image: service.image,
      running: running,
      lanEnabled: service.lanEnabled,
      portLabel: service.port > 0 ? '${service.port}' : 'none',
      series: series,
    );
  }
}

Future<void> _openUrl(BuildContext context, String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) {
    return;
  }

  final uri = Uri.tryParse(trimmed);
  if (uri == null) {
    return;
  }

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open service link')),
    );
  }
}

class _DashboardMetrics {
  const _DashboardMetrics({
    required this.hostCpuPercent,
    required this.hostMemoryPercent,
    required this.hostStoragePercent,
    required this.containerCpuPercent,
    required this.containerMemoryBytes,
    required this.containerNetworkBytes,
    required this.liveStatsCount,
    required this.cpuSeries,
    required this.memorySeries,
    required this.networkSeries,
    required this.storageSeries,
  });

  final double hostCpuPercent;
  final double hostMemoryPercent;
  final double hostStoragePercent;
  final double containerCpuPercent;
  final double containerMemoryBytes;
  final double containerNetworkBytes;
  final int liveStatsCount;
  final List<double> cpuSeries;
  final List<double> memorySeries;
  final List<double> networkSeries;
  final List<double> storageSeries;
}

class _HostMetrics {
  const _HostMetrics({
    required this.cpuPercent,
    required this.memoryPercent,
    required this.storagePercent,
  });

  final double cpuPercent;
  final double memoryPercent;
  final double storagePercent;
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
  final cores = onlineCpus > 0
      ? onlineCpus
      : (_listValue(cpuUsage['percpu_usage']).isNotEmpty ? _listValue(cpuUsage['percpu_usage']).length.toDouble() : 1);

  if (cpuDelta <= 0 || systemDelta <= 0) {
    return 0;
  }

  return (cpuDelta / systemDelta) * cores * 100;
}

double _memoryUsageBytesFromStats(Map<String, dynamic> raw) {
  final memory = _mapValue(raw['memory_stats']);
  return _asDouble(memory['usage']);
}

double _networkBytesFromStats(Map<String, dynamic> raw) {
  final networks = _mapValue(raw['networks']);
  var total = 0.0;
  for (final value in networks.values) {
    final adapter = _mapValue(value);
    total += _asDouble(adapter['rx_bytes']);
    total += _asDouble(adapter['tx_bytes']);
  }
  return total;
}

Map<String, dynamic> _mapValue(dynamic value) {
  if (value is Map<String, dynamic>) {
    return value;
  }
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  return const {};
}

List<dynamic> _listValue(dynamic value) {
  if (value is List) {
    return value;
  }
  return const [];
}

double _asDouble(dynamic value) {
  if (value is num) {
    return value.toDouble();
  }
  if (value is String) {
    return double.tryParse(value) ?? 0;
  }
  return 0;
}

double _bytesToMegabytes(double value) => value / (1024 * 1024);
