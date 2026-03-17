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
import 'service_details_sheet.dart';

const _dockerDesktopStoreUrl =
    'https://apps.microsoft.com/detail/xp8cbj40xlbwkx?hl=en-GB&gl=GB';
const _virtualizationHelpUrl =
    'https://support.microsoft.com/en-us/windows/enable-virtualization-on-windows-c5578302-6e43-4b4b-a449-8ced115f58e1';
const _forceDashboardVirtualizationPreview = false;

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
  Timer? _graphTimer;
  final List<double> _cpuHistory = [];
  final List<double> _memoryHistory = [];
  final List<double> _networkHistory = [];
  final List<double> _storageHistory = [];
  double _latestCpuSample = 0;
  double _latestMemorySample = 0;
  double _latestNetworkSample = 0;
  double _latestStorageSample = 0;
  double? _lastNetworkObservedBytes;
  DateTime? _lastNetworkObservedAt;
  int _graphTick = 0;

  @override
  void initState() {
    super.initState();
    _metricsFuture = _loadMetrics();
    _refreshTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      if (!mounted) return;
      setState(() {
        _metricsFuture = _loadMetrics();
      });
    });
    _graphTimer = Timer.periodic(const Duration(milliseconds: 350), (_) {
      if (!mounted) return;
      setState(() {
        _graphTick++;
        _pushHistory(_cpuHistory, _latestCpuSample);
        _pushHistory(_memoryHistory, _latestMemorySample);
        _pushHistory(_networkHistory, _latestNetworkSample);
        _pushHistory(_storageHistory, _latestStorageSample);
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
    _graphTimer?.cancel();
    super.dispose();
  }

  Future<_DashboardMetrics> _loadMetrics() async {
    final services = widget.state.services;
    final definitions = widget.state.definitions;
    final serviceStats = await Future.wait(
      services.map((service) async {
        try {
          final stats = await _api.serviceStats(service.id);
          return MapEntry(service, stats);
        } catch (_) {
          return null;
        }
      }),
    );

    final usableStats = serviceStats
        .whereType<MapEntry<GoService, GoStatsResponse>>()
        .toList();
    final hostMetrics = await _loadHostMetrics();
    final storageMetrics = await _loadServaStorageMetrics(definitions);

    final liveServiceMetrics = <String, _ServiceLiveMetrics>{};
    var containerCpu = 0.0;
    var containerMemoryBytes = 0.0;
    var containerNetworkRxBytes = 0.0;
    var containerNetworkTxBytes = 0.0;

    for (final entry in usableStats) {
      final service = entry.key;
      final raw = entry.value.raw;
      final serviceMetrics = _ServiceLiveMetrics(
        cpuPercent: _cpuPercentFromStats(raw),
        memoryUsageBytes: _memoryUsageBytesFromStats(raw),
        memoryLimitBytes: _memoryLimitBytesFromStats(raw),
        networkRxBytes: _networkRxBytesFromStats(raw),
        networkTxBytes: _networkTxBytesFromStats(raw),
        readAt: entry.value.readAt,
      );
      liveServiceMetrics[service.id] = serviceMetrics;
      containerCpu += serviceMetrics.cpuPercent;
      containerMemoryBytes += serviceMetrics.memoryUsageBytes;
      containerNetworkRxBytes += serviceMetrics.networkRxBytes;
      containerNetworkTxBytes += serviceMetrics.networkTxBytes;
    }

    final totalNetworkBytes = containerNetworkRxBytes + containerNetworkTxBytes;
    final now = DateTime.now();
    final previousNetworkBytes = _lastNetworkObservedBytes;
    final previousNetworkAt = _lastNetworkObservedAt;
    var networkRateBytesPerSecond = 0.0;
    if (previousNetworkBytes != null && previousNetworkAt != null) {
      final elapsedMs = now.difference(previousNetworkAt).inMilliseconds;
      final deltaBytes = totalNetworkBytes - previousNetworkBytes;
      if (elapsedMs > 0 && deltaBytes >= 0) {
        networkRateBytesPerSecond = deltaBytes / (elapsedMs / 1000);
      }
    }
    _lastNetworkObservedBytes = totalNetworkBytes;
    _lastNetworkObservedAt = now;

    _latestCpuSample = containerCpu;
    _latestMemorySample = _bytesToMegabytes(containerMemoryBytes);
    _latestNetworkSample = _bytesToMegabytes(networkRateBytesPerSecond);
    _latestStorageSample = _bytesToMegabytes(storageMetrics.totalBytes);

    if (_cpuHistory.isEmpty) {
      _pushHistory(_cpuHistory, _latestCpuSample);
      _pushHistory(_memoryHistory, _latestMemorySample);
      _pushHistory(_networkHistory, _latestNetworkSample);
      _pushHistory(_storageHistory, _latestStorageSample);
    }

    return _DashboardMetrics(
      hostCpuPercent: hostMetrics.cpuPercent,
      hostMemoryPercent: hostMetrics.memoryPercent,
      hostStoragePercent: hostMetrics.storagePercent,
      hostMemoryUsedBytes: hostMetrics.memoryUsedBytes,
      hostMemoryTotalBytes: hostMetrics.memoryTotalBytes,
      hostStorageUsedBytes: hostMetrics.storageUsedBytes,
      hostStorageTotalBytes: hostMetrics.storageTotalBytes,
      servaStorageUsedBytes: storageMetrics.totalBytes,
      containerCpuPercent: containerCpu,
      containerMemoryBytes: containerMemoryBytes,
      containerNetworkRxBytes: containerNetworkRxBytes,
      containerNetworkTxBytes: containerNetworkTxBytes,
      liveStatsCount: usableStats.length,
      liveServiceMetrics: liveServiceMetrics,
      serviceStorageBytes: storageMetrics.serviceBytes,
      cpuSeries: List<double>.from(_cpuHistory),
      memorySeries: List<double>.from(_memoryHistory),
      networkSeries: List<double>.from(_networkHistory),
      storageSeries: List<double>.from(_storageHistory),
    );
  }

  Future<_HostMetrics> _loadHostMetrics() async {
    if (!Platform.isWindows) {
      return const _HostMetrics(
        cpuPercent: 0,
        memoryPercent: 0,
        storagePercent: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        storageUsedBytes: 0,
        storageTotalBytes: 0,
      );
    }

    try {
      final userProfile = Platform.environment['USERPROFILE'] ?? '';
      final documentsPath = userProfile.isNotEmpty
          ? '$userProfile\\Documents\\Serva'
          : 'C:\\';
      final drive = documentsPath.length >= 2
          ? documentsPath.substring(0, 2)
          : 'C:';
      final command =
          r'''
$cpu = (Get-CimInstance Win32_Processor | Measure-Object -Property LoadPercentage -Average).Average
$os = Get-CimInstance Win32_OperatingSystem
$totalMemory = [double]$os.TotalVisibleMemorySize
$freeMemory = [double]$os.FreePhysicalMemory
$memoryPercent = if ($totalMemory -gt 0) { (($totalMemory - $freeMemory) / $totalMemory) * 100 } else { 0 }
$drive = Get-CimInstance Win32_LogicalDisk -Filter "DeviceID='__DRIVE__'"
$storagePercent = if ($drive -and [double]$drive.Size -gt 0) { (([double]$drive.Size - [double]$drive.FreeSpace) / [double]$drive.Size) * 100 } else { 0 }
$usedMemory = ($totalMemory - $freeMemory) * 1KB
$totalMemoryBytes = $totalMemory * 1KB
$freeSpace = if ($drive) { [double]$drive.FreeSpace } else { 0 }
$driveSize = if ($drive) { [double]$drive.Size } else { 0 }
$usedStorage = if ($driveSize -gt 0) { $driveSize - $freeSpace } else { 0 }
@{
  cpu = [math]::Round($cpu, 1)
  memory = [math]::Round($memoryPercent, 1)
  storage = [math]::Round($storagePercent, 1)
  memoryUsed = [math]::Round($usedMemory, 0)
  memoryTotal = [math]::Round($totalMemoryBytes, 0)
  storageUsed = [math]::Round($usedStorage, 0)
  storageTotal = [math]::Round($driveSize, 0)
} | ConvertTo-Json -Compress
'''
              .replaceAll('__DRIVE__', drive);

      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        command,
      ]);

      if (result.exitCode != 0) {
        return const _HostMetrics(
          cpuPercent: 0,
          memoryPercent: 0,
          storagePercent: 0,
          memoryUsedBytes: 0,
          memoryTotalBytes: 0,
          storageUsedBytes: 0,
          storageTotalBytes: 0,
        );
      }

      final raw = result.stdout.toString().trim();
      if (raw.isEmpty) {
        return const _HostMetrics(
          cpuPercent: 0,
          memoryPercent: 0,
          storagePercent: 0,
          memoryUsedBytes: 0,
          memoryTotalBytes: 0,
          storageUsedBytes: 0,
          storageTotalBytes: 0,
        );
      }

      final json = jsonDecode(raw);
      if (json is! Map) {
        return const _HostMetrics(
          cpuPercent: 0,
          memoryPercent: 0,
          storagePercent: 0,
          memoryUsedBytes: 0,
          memoryTotalBytes: 0,
          storageUsedBytes: 0,
          storageTotalBytes: 0,
        );
      }

      return _HostMetrics(
        cpuPercent: _asDouble(json['cpu']),
        memoryPercent: _asDouble(json['memory']),
        storagePercent: _asDouble(json['storage']),
        memoryUsedBytes: _asDouble(json['memoryUsed']),
        memoryTotalBytes: _asDouble(json['memoryTotal']),
        storageUsedBytes: _asDouble(json['storageUsed']),
        storageTotalBytes: _asDouble(json['storageTotal']),
      );
    } catch (_) {
      return const _HostMetrics(
        cpuPercent: 0,
        memoryPercent: 0,
        storagePercent: 0,
        memoryUsedBytes: 0,
        memoryTotalBytes: 0,
        storageUsedBytes: 0,
        storageTotalBytes: 0,
      );
    }
  }

  Future<_ServaStorageMetrics> _loadServaStorageMetrics(
    List<GoServiceDefinition> definitions,
  ) async {
    final basePath = _servaManagedBasePath();
    final serviceRoots = <String, String>{};

    for (final definition in definitions) {
      final root = _serviceMountRootFromDefinition(definition);
      if (root != null && root.startsWith(basePath)) {
        serviceRoots[definition.name] = root;
      }
    }

    final command = StringBuffer()
      ..writeln("\$base = '${_psEscape(basePath)}'")
      ..writeln("\$result = [ordered]@{}")
      ..writeln("if (Test-Path -LiteralPath \$base) {")
      ..writeln(
        "  \$total = (Get-ChildItem -LiteralPath \$base -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum",
      )
      ..writeln(
        "  \$result.total = if (\$null -eq \$total) { 0 } else { [double]\$total }",
      )
      ..writeln("} else {")
      ..writeln("  \$result.total = 0")
      ..writeln("}")
      ..writeln("\$services = [ordered]@{}");

    serviceRoots.forEach((name, path) {
      command
        ..writeln("\$servicePath = '${_psEscape(path)}'")
        ..writeln("if (Test-Path -LiteralPath \$servicePath) {")
        ..writeln(
          "  \$sum = (Get-ChildItem -LiteralPath \$servicePath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum",
        )
        ..writeln(
          "  \$services['${_psEscape(name)}'] = if (\$null -eq \$sum) { 0 } else { [double]\$sum }",
        )
        ..writeln("} else {")
        ..writeln("  \$services['${_psEscape(name)}'] = 0")
        ..writeln("}");
    });

    command
      ..writeln("\$result.services = \$services")
      ..writeln("\$result | ConvertTo-Json -Compress");

    try {
      final result = await Process.run('powershell', [
        '-NoProfile',
        '-Command',
        command.toString(),
      ]);

      if (result.exitCode != 0) {
        return const _ServaStorageMetrics(totalBytes: 0, serviceBytes: {});
      }

      final raw = result.stdout.toString().trim();
      if (raw.isEmpty) {
        return const _ServaStorageMetrics(totalBytes: 0, serviceBytes: {});
      }

      final json = jsonDecode(raw);
      if (json is! Map) {
        return const _ServaStorageMetrics(totalBytes: 0, serviceBytes: {});
      }

      final servicesJson = json['services'];
      final serviceBytes = <String, double>{};
      if (servicesJson is Map) {
        for (final entry in servicesJson.entries) {
          serviceBytes[entry.key.toString()] = _asDouble(entry.value);
        }
      }

      return _ServaStorageMetrics(
        totalBytes: _asDouble(json['total']),
        serviceBytes: serviceBytes,
      );
    } catch (_) {
      return const _ServaStorageMetrics(totalBytes: 0, serviceBytes: {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final width = MediaQuery.of(context).size.width;
    final uiScale = _dashboardUiScale(width);
    final services = widget.state.services;
    final definitions = widget.state.definitions;
    final lastMessage = widget.state.lastMessage;
    final runningServices = services
        .where((service) => service.state.toLowerCase() == 'running')
        .length;
    final lanServices = services.where((service) => service.lanEnabled).length;
    final savedOnlyDefinitions = definitions
        .where((definition) => !definition.isDeployed)
        .length;
    final showDashboardSupportBanner =
        _forceDashboardVirtualizationPreview ||
        _looksLikeDockerUnavailable(lastMessage) ||
        _looksLikeVirtualizationIssue(lastMessage);

    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF08111F), Color(0xFF101B31), Color(0xFF171E2D)],
        ),
      ),
      child: ListView(
        padding: EdgeInsets.all(8 * uiScale),
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
          if (showDashboardSupportBanner) ...[
            SizedBox(height: 8 * uiScale),
            _DashboardSupportBanner(message: lastMessage ?? '', scale: uiScale),
          ],
          SizedBox(height: 8 * uiScale),
          _HeroPanel(
            healthOk: widget.state.healthOk,
            runningServices: runningServices,
            totalServices: services.length,
            savedDefinitions: savedOnlyDefinitions,
            lanServices: lanServices,
            throughputSeries: _buildSeriesFromSeed(
              services.length * 17 + 11,
              18,
              18,
            ),
            scale: uiScale,
          ),
          SizedBox(height: 8 * uiScale),
          FutureBuilder<_DashboardMetrics>(
            future: _metricsFuture,
            builder: (context, snapshot) {
              final metrics = snapshot.data;
              final containerCpu = _boundedValue(
                (metrics?.containerCpuPercent ?? 0).round(),
                0,
                999,
              );
              final networkMegabytes = _bytesToMegabytes(
                (metrics?.containerNetworkRxBytes ?? 0) +
                    (metrics?.containerNetworkTxBytes ?? 0),
              );
              final containerMemoryMegabytes = _bytesToMegabytes(
                metrics?.containerMemoryBytes ?? 0,
              );
              final liveStatsCount = metrics?.liveStatsCount ?? 0;
              final cpuSeries = _cpuHistory.isEmpty
                  ? (metrics?.cpuSeries ?? const <double>[])
                  : _cpuHistory;
              final memorySeries = _memoryHistory.isEmpty
                  ? (metrics?.memorySeries ?? const <double>[])
                  : _memoryHistory;
              final networkSeries = _networkHistory.isEmpty
                  ? (metrics?.networkSeries ?? const <double>[])
                  : _networkHistory;
              final storageSeries = _storageHistory.isEmpty
                  ? (metrics?.storageSeries ?? const <double>[])
                  : _storageHistory;

              final crossAxisCount = width >= 1400
                  ? 4
                  : width >= 1000
                  ? 4
                  : 2;

              return GridView.count(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8 * uiScale,
                mainAxisSpacing: 8 * uiScale,
                shrinkWrap: true,
                childAspectRatio: crossAxisCount >= 4 ? 1.95 : 2.15,
                physics: const NeverScrollableScrollPhysics(),
                children: [
                  _StatCard(
                    label: 'Serva CPU',
                    value:
                        '${metrics?.containerCpuPercent.toStringAsFixed(1) ?? '0.0'}%',
                    caption: liveStatsCount == 0
                        ? 'No live container CPU data yet'
                        : 'Aggregate CPU across active services',
                    color: const Color(0xFF4CC9F0),
                    icon: Icons.memory_rounded,
                    series: cpuSeries,
                    graphTick: _graphTick,
                    scale: uiScale,
                    footer:
                        'Host load context: ${metrics?.hostCpuPercent.toStringAsFixed(1) ?? '0.0'}%',
                  ),
                  _StatCard(
                    label: 'Serva Memory',
                    value: _formatBytes(metrics?.containerMemoryBytes ?? 0),
                    caption: liveStatsCount == 0
                        ? 'No live container memory data yet'
                        : 'Total memory used by active services',
                    color: const Color(0xFF80ED99),
                    icon: Icons.stacked_line_chart_rounded,
                    series: memorySeries,
                    graphTick: _graphTick,
                    scale: uiScale,
                    footer:
                        'Host memory context: ${_formatBytes(metrics?.hostMemoryUsedBytes ?? 0)} / ${_formatBytes(metrics?.hostMemoryTotalBytes ?? 0)}',
                  ),
                  _StatCard(
                    label: 'Serva Network',
                    value: _formatBytes(
                      (metrics?.containerNetworkRxBytes ?? 0) +
                          (metrics?.containerNetworkTxBytes ?? 0),
                    ),
                    caption: liveStatsCount == 0
                        ? 'No live Docker stats yet'
                        : 'Live network usage across active services',
                    color: const Color(0xFFFFC857),
                    icon: Icons.wifi_tethering_rounded,
                    series: networkSeries,
                    graphTick: _graphTick,
                    scale: uiScale,
                    footer: liveStatsCount == 0
                        ? 'Waiting for container stats'
                        : '${_formatBytes(metrics?.containerNetworkRxBytes ?? 0)} rx / ${_formatBytes(metrics?.containerNetworkTxBytes ?? 0)} tx  |  ${_formatBytes(_megabytesToBytes(_latestNetworkSample))}/s',
                  ),
                  _StatCard(
                    label: 'Serva Storage',
                    value: _formatBytes(metrics?.servaStorageUsedBytes ?? 0),
                    caption: 'Serva data stored under Documents\\Serva',
                    color: const Color(0xFFFF7B72),
                    icon: Icons.storage_rounded,
                    series: storageSeries,
                    graphTick: _graphTick,
                    scale: uiScale,
                    footer:
                        'Drive usage: ${_formatBytes(metrics?.hostStorageUsedBytes ?? 0)} / ${_formatBytes(metrics?.hostStorageTotalBytes ?? 0)}',
                  ),
                ],
              );
            },
          ),
          LayoutBuilder(
            builder: (context, constraints) {
              final narrow = constraints.maxWidth < 900;
              if (narrow) {
                return Column(
                  children: [
                    _ActivityPanel(
                      services: services
                          .map((service) => _ServicePulse.fromService(service))
                          .toList(),
                      scale: uiScale,
                    ),
                    SizedBox(height: 8 * uiScale),
                    _MissionPanel(
                      healthOk: widget.state.healthOk,
                      lastMessage: lastMessage,
                      savedDefinitions: savedOnlyDefinitions,
                      services: services.length,
                      scale: uiScale,
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
                      services: services
                          .map((service) => _ServicePulse.fromService(service))
                          .toList(),
                      scale: uiScale,
                    ),
                  ),
                  SizedBox(width: 8 * uiScale),
                  Expanded(
                    flex: 2,
                    child: _MissionPanel(
                      healthOk: widget.state.healthOk,
                      lastMessage: lastMessage,
                      savedDefinitions: savedOnlyDefinitions,
                      services: services.length,
                      scale: uiScale,
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

  List<double> _pushHistory(
    List<double> target,
    double sample, {
    int maxPoints = 36,
  }) {
    target.add(sample);
    if (target.length > maxPoints) {
      target.removeAt(0);
    }
    return List<double>.from(target);
  }

  static List<double> _buildSeriesFromSeed(
    int seed,
    int points,
    int amplitude,
  ) {
    final random = Random(seed);
    return List<double>.generate(points, (index) {
      final base = 42 + sin((index + seed) / 2.2) * amplitude;
      final noise = random.nextDouble() * 12 - 6;
      return (base + noise).clamp(8, 96).toDouble();
    });
  }
}

class _ServiceControlPanel extends StatelessWidget {
  const _ServiceControlPanel({
    required this.services,
    required this.liveMetrics,
    required this.serviceStorageBytes,
  });

  final List<GoService> services;
  final Map<String, _ServiceLiveMetrics> liveMetrics;
  final Map<String, double> serviceStorageBytes;

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
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
              child: const Text(
                'No running or saved containers are active yet. Launch one from the Launch tab.',
              ),
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
                    childAspectRatio: crossAxisCount == 1
                        ? 3.4
                        : crossAxisCount >= 4
                        ? 1.56
                        : crossAxisCount == 3
                        ? 1.72
                        : 2.3,
                  ),
                  itemBuilder: (context, index) {
                    final service = services[index];
                    return _ServiceCommandTile(
                      service: service,
                      liveMetrics: liveMetrics[service.id],
                      storageBytes: serviceStorageBytes[service.name],
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
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
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
  const _ServiceCommandTile({
    required this.service,
    this.liveMetrics,
    this.storageBytes,
  });

  final GoService service;
  final _ServiceLiveMetrics? liveMetrics;
  final double? storageBytes;

  bool get _isRunning => service.state.toLowerCase() == 'running';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<MainBloc>();
    final accent = _isRunning
        ? const Color(0xFF80ED99)
        : const Color(0xFFFFC857);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF17233C),
            Color.alphaBlend(
              accent.withValues(alpha: 0.12),
              const Color(0xFF101A2D),
            ),
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
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.image,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
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
                icon: service.localUrl.trim().isNotEmpty
                    ? Icons.open_in_new_rounded
                    : Icons.tune_rounded,
                onTap: () {
                  if (service.localUrl.trim().isNotEmpty) {
                    _openUrl(context, service.localUrl);
                  }
                },
              ),
              _ActionChip(
                label: 'Details',
                icon: Icons.tune_rounded,
                onTap: () => showServiceDetailsSheet(context, service),
              ),
              _ActionChip(
                label: _isRunning ? 'Pause' : 'Start',
                icon: _isRunning
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
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
                onTap: () => bloc.add(
                  MainExposeLanRequested(
                    id: service.id,
                    enabled: !service.lanEnabled,
                  ),
                ),
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
          if (liveMetrics != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _ServiceMeta(
                  label: 'CPU',
                  value: '${liveMetrics!.cpuPercent.toStringAsFixed(1)}%',
                ),
                _ServiceMeta(
                  label: 'RAM',
                  value: liveMetrics!.memoryLimitBytes > 0
                      ? '${_formatBytes(liveMetrics!.memoryUsageBytes)} / ${_formatBytes(liveMetrics!.memoryLimitBytes)}'
                      : _formatBytes(liveMetrics!.memoryUsageBytes),
                ),
                _ServiceMeta(
                  label: 'Net',
                  value:
                      '${_formatBytes(liveMetrics!.networkRxBytes)} rx / ${_formatBytes(liveMetrics!.networkTxBytes)} tx',
                ),
                _ServiceMeta(
                  label: 'Data',
                  value: _formatBytes(storageBytes ?? 0),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              _ServiceMeta(
                label: 'Port',
                value: service.port > 0 ? '${service.port}' : 'none',
              ),
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
        content: Text(
          'This will remove "${service.name}" from the current deployment.',
        ),
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
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
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
                  onTap: () =>
                      bloc.add(MainRecreateRequested(id: definition.id)),
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
    final color = destructive
        ? const Color(0xFFFF7B72)
        : theme.colorScheme.primary;

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
          style: theme.textTheme.bodyMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
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
    required this.scale,
  });

  final bool healthOk;
  final int runningServices;
  final int totalServices;
  final int savedDefinitions;
  final int lanServices;
  final List<double> throughputSeries;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101D36), Color(0xFF0D1527)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10 * scale,
                height: 10 * scale,
                decoration: BoxDecoration(
                  color: healthOk
                      ? const Color(0xFF80ED99)
                      : const Color(0xFFFF7B72),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (healthOk
                                  ? const Color(0xFF80ED99)
                                  : const Color(0xFFFF7B72))
                              .withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8 * scale),
              Text(
                healthOk ? 'System stable' : 'Attention needed',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize: (theme.textTheme.titleMedium?.fontSize ?? 16) * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 2 * scale),
          Text(
            healthOk
                ? 'Backend reachable and ready.'
                : 'Docker or the backend needs attention.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: (theme.textTheme.bodySmall?.fontSize ?? 16) * scale,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
          SizedBox(height: 6 * scale),
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
                      scale: scale,
                    ),
                    SizedBox(height: 3 * scale),
                    _MiniStatStrip(
                      label: 'Tracked',
                      value: '$totalServices',
                      accent: const Color(0xFF80ED99),
                      scale: scale,
                    ),
                    SizedBox(height: 3 * scale),
                    _MiniStatStrip(
                      label: 'Saved',
                      value: '$savedDefinitions',
                      accent: const Color(0xFFFFC857),
                      scale: scale,
                    ),
                    SizedBox(height: 3 * scale),
                    _MiniStatStrip(
                      label: 'LAN',
                      value: '$lanServices',
                      accent: const Color(0xFFFF7B72),
                      scale: scale,
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
                      scale: scale,
                    ),
                  ),
                  SizedBox(width: 3 * scale),
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'Tracked',
                      value: '$totalServices',
                      accent: const Color(0xFF80ED99),
                      scale: scale,
                    ),
                  ),
                  SizedBox(width: 3 * scale),
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'Saved',
                      value: '$savedDefinitions',
                      accent: const Color(0xFFFFC857),
                      scale: scale,
                    ),
                  ),
                  SizedBox(width: 3 * scale),
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'LAN',
                      value: '$lanServices',
                      accent: const Color(0xFFFF7B72),
                      scale: scale,
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
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
    required this.series,
    required this.graphTick,
    required this.scale,
    this.footer,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;
  final List<double> series;
  final int graphTick;
  final double scale;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1728).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8 * scale),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14 * scale),
                ),
                child: Icon(icon, color: color),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize:
                        (theme.textTheme.labelMedium?.fontSize ?? 16) * scale,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 86 * scale,
            width: double.infinity,
            child: CustomPaint(
              painter: _HistoryBarsPainter(
                values: series,
                color: color,
                tick: graphTick,
              ),
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize:
                  (theme.textTheme.headlineMedium?.fontSize ?? 28) * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 18) * scale,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (footer != null) ...[
            SizedBox(height: 2 * scale),
            Text(
              footer!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 17) * scale,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
              ),
            ),
          ],
          SizedBox(height: 4 * scale),
        ],
      ),
    );
  }
}

class _ActivityPanel extends StatelessWidget {
  const _ActivityPanel({required this.services, required this.scale});

  final List<_ServicePulse> services;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Live activity',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: (theme.textTheme.titleLarge?.fontSize ?? 22) * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            'A stylized pulse view of the services Serva is tracking right now.',
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 17) * scale,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: 6 * scale),
          if (services.isEmpty)
            Container(
              padding: EdgeInsets.all(8 * scale),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16 * scale),
              ),
              child: const Text(
                'No live services yet. Create one and this dashboard will light up.',
              ),
            )
          else
            for (var i = 0; i < services.length; i++) ...[
              _ActivityRow(service: services[i], scale: scale),
              if (i != services.length - 1) SizedBox(height: 6 * scale),
            ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.service, required this.scale});

  final _ServicePulse service;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = service.running
        ? const Color(0xFF80ED99)
        : const Color(0xFFFF7B72);

    return Container(
      padding: EdgeInsets.all(10 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(18 * scale),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  service.name,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontSize:
                        (theme.textTheme.titleMedium?.fontSize ?? 16) * scale,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: 10 * scale,
                  vertical: 6 * scale,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  service.running ? 'RUNNING' : 'IDLE',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontSize:
                        (theme.textTheme.labelSmall?.fontSize ?? 16) * scale,
                    color: accent,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 4 * scale),
          SizedBox(
            height: 20 * scale,
            child: CustomPaint(
              painter: _LineChartPainter(values: service.series, color: accent),
            ),
          ),
          SizedBox(height: 3 * scale),
          Row(
            children: [
              _InlineMetric(
                label: 'Port',
                value: service.portLabel,
                scale: scale,
              ),
              SizedBox(width: 8 * scale),
              _InlineMetric(
                label: 'Mode',
                value: service.lanEnabled ? 'LAN' : 'Local',
                scale: scale,
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: _InlineMetric(
                  label: 'Image',
                  value: service.image,
                  scale: scale,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DashboardSupportBanner extends StatelessWidget {
  const _DashboardSupportBanner({required this.message, required this.scale});

  final String message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final virtualizationIssue = _looksLikeVirtualizationIssue(message);
    final dockerUnavailable = _looksLikeDockerUnavailable(message);
    final accent = virtualizationIssue
        ? const Color(0xFFFFC857)
        : const Color(0xFF4CC9F0);

    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            virtualizationIssue ? Icons.memory_rounded : Icons.download_rounded,
            color: accent,
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  virtualizationIssue
                      ? 'Virtualization may be required'
                      : 'Docker Desktop may be required',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize: (theme.textTheme.titleSmall?.fontSize ?? 17) * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  virtualizationIssue
                      ? 'Docker Desktop needs virtualization enabled to run. You may need to enable virtualization in Windows and in your BIOS/UEFI settings.'
                      : 'Serva could not reach Docker Desktop. Install it or make sure it is running, then refresh the dashboard.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize: (theme.textTheme.bodySmall?.fontSize ?? 16) * scale,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
                  ),
                ),
                if (message.trim().isNotEmpty) ...[
                  SizedBox(height: 4 * scale),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize: (theme.textTheme.bodySmall?.fontSize ?? 16) * scale,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.56,
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 8 * scale),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (dockerUnavailable)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openUrl(context, _dockerDesktopStoreUrl),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Install Docker Desktop'),
                      ),
                    if (virtualizationIssue)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openUrl(context, _virtualizationHelpUrl),
                        icon: const Icon(Icons.memory_rounded),
                        label: const Text('Virtualization Help'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => context.read<MainBloc>().add(
                        const MainLoadRequested(),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionPanel extends StatelessWidget {
  const _MissionPanel({
    required this.healthOk,
    required this.lastMessage,
    required this.savedDefinitions,
    required this.services,
    required this.scale,
  });

  final bool healthOk;
  final String? lastMessage;
  final int savedDefinitions;
  final int services;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dockerUnavailable = _looksLikeDockerUnavailable(lastMessage);
    final virtualizationIssue = _looksLikeVirtualizationIssue(lastMessage);
    final dockerConnected = healthOk && !dockerUnavailable;
    final virtualizationReady = !virtualizationIssue;
    final controlPlaneReady = healthOk;
    final readinessChecks = [
      dockerConnected,
      virtualizationReady,
      controlPlaneReady,
    ];
    final readinessScore =
        ((readinessChecks.where((check) => check).length /
                    readinessChecks.length) *
                100)
            .round();

    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mission profile',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: (theme.textTheme.titleLarge?.fontSize ?? 26) * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6 * scale),
          Center(
            child: SizedBox(
              width: 156 * scale,
              height: 156 * scale,
              child: CustomPaint(
                painter: _GaugePainter(value: readinessScore / 100),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$readinessScore%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize:
                              (theme.textTheme.headlineMedium?.fontSize ?? 40) *
                              scale,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        'Readiness',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize:
                              (theme.textTheme.bodyMedium?.fontSize ?? 20) * scale,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 6 * scale),
          _ChecklistItem(
            title: dockerConnected ? 'Docker connected' : 'Docker unavailable',
            subtitle: dockerConnected
                ? 'Docker Desktop is reachable from Serva.'
                : 'Install or start Docker Desktop so Serva can manage services.',
            success: dockerConnected,
            scale: scale,
          ),
          SizedBox(height: 4 * scale),
          _ChecklistItem(
            title: virtualizationReady
                ? 'Virtualization ready'
                : 'Virtualization required',
            subtitle: virtualizationReady
                ? 'Hardware virtualization looks ready for Docker Desktop.'
                : 'You may need to enable virtualization in Windows and BIOS/UEFI.',
            success: virtualizationReady,
            scale: scale,
          ),
          SizedBox(height: 4 * scale),
          _ChecklistItem(
            title: controlPlaneReady
                ? 'Control plane reachable'
                : 'Control plane degraded',
            subtitle: controlPlaneReady
                ? 'Serva can talk to the local daemon.'
                : 'Backend or Docker needs attention before services can be managed.',
            success: controlPlaneReady,
            scale: scale,
          ),
          SizedBox(height: 4 * scale),
          _ChecklistItem(
            title: '$services services, $savedDefinitions saved',
            subtitle:
                'Inventory count for live services and saved recovery definitions.',
            success: services > 0 || savedDefinitions > 0,
            scale: scale,
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
    required this.scale,
  });

  final String title;
  final String subtitle;
  final bool success;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF80ED99) : const Color(0xFFFFC857);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2 * scale),
          child: Icon(
            success ? Icons.verified_rounded : Icons.timelapse_rounded,
            color: color,
            size: 20 * scale,
          ),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize: (theme.textTheme.titleLarge?.fontSize ?? 22) * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2 * scale),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: (theme.textTheme.bodyLarge?.fontSize ?? 19) * scale,
                  fontWeight: FontWeight.w500,
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
    required this.scale,
  });

  final String label;
  final String value;
  final Color accent;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Row(
        children: [
          Container(
            width: 8 * scale,
            height: 8 * scale,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize:
                    (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 17) *
                    scale,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(
              fontSize:
                  (Theme.of(context).textTheme.titleSmall?.fontSize ?? 17) *
                  scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    required this.scale,
  });

  final String label;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: (theme.textTheme.labelSmall?.fontSize ?? 16) * scale,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 17) * scale,
            fontWeight: FontWeight.w600,
          ),
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

class _HistoryBarsPainter extends CustomPainter {
  _HistoryBarsPainter({
    required this.values,
    required this.color,
    required this.tick,
  });

  final List<double> values;
  final Color color;
  final int tick;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;

    final normalized = _normalizeSeries(values);
    final count = normalized.length;
    final gap = 2.0;
    final barWidth = max(2.0, (size.width - ((count - 1) * gap)) / count);
    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.035)
      ..strokeWidth = 1;
    final basePaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.06)
      ..style = PaintingStyle.fill;
    final barPaint = Paint()..style = PaintingStyle.fill;
    final cursorPaint = Paint()
      ..color = color.withValues(alpha: 0.9)
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round;
    final cursorGlowPaint = Paint()
      ..color = color.withValues(alpha: 0.18)
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round;

    for (var row = 1; row < 4; row++) {
      final y = (size.height / 4) * row;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    for (var i = 0; i < count; i++) {
      final x = i * (barWidth + gap);
      final barHeight = max(3.0, (normalized[i] / 100) * size.height);
      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, size.height - barHeight, barWidth, barHeight),
        const Radius.circular(3),
      );
      final baseRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, 0, barWidth, size.height),
        const Radius.circular(3),
      );

      canvas.drawRRect(baseRect, basePaint);
      final isLatest = i == count - 1;
      final ageFactor = count <= 1 ? 1.0 : (i / (count - 1));
      barPaint.color = isLatest
          ? color
          : color.withValues(alpha: 0.18 + (ageFactor * 0.55));
      canvas.drawRRect(rect, barPaint);
    }

    final pulse = ((tick % 6) / 5).clamp(0, 1).toDouble();
    final cursorX = max(0.0, size.width - (barWidth * (0.9 - (pulse * 0.2))));
    canvas.drawLine(
      Offset(cursorX, 6),
      Offset(cursorX, size.height - 6),
      cursorGlowPaint,
    );
    canvas.drawLine(
      Offset(cursorX, 8),
      Offset(cursorX, size.height - 8),
      cursorPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HistoryBarsPainter oldDelegate) {
    return oldDelegate.values != values ||
        oldDelegate.color != color ||
        oldDelegate.tick != tick;
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
        colors: [color.withValues(alpha: 0.35), color.withValues(alpha: 0.02)],
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
        colors: [Color(0xFF4CC9F0), Color(0xFF80ED99), Color(0xFFFFC857)],
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
      (index) =>
          (base + sin((index + seed) / 2) * 14 + (random.nextDouble() * 9 - 4))
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
  if (_forceDashboardVirtualizationPreview) {
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
    required this.hostMemoryUsedBytes,
    required this.hostMemoryTotalBytes,
    required this.hostStorageUsedBytes,
    required this.hostStorageTotalBytes,
    required this.servaStorageUsedBytes,
    required this.containerCpuPercent,
    required this.containerMemoryBytes,
    required this.containerNetworkRxBytes,
    required this.containerNetworkTxBytes,
    required this.liveStatsCount,
    required this.liveServiceMetrics,
    required this.serviceStorageBytes,
    required this.cpuSeries,
    required this.memorySeries,
    required this.networkSeries,
    required this.storageSeries,
  });

  final double hostCpuPercent;
  final double hostMemoryPercent;
  final double hostStoragePercent;
  final double hostMemoryUsedBytes;
  final double hostMemoryTotalBytes;
  final double hostStorageUsedBytes;
  final double hostStorageTotalBytes;
  final double servaStorageUsedBytes;
  final double containerCpuPercent;
  final double containerMemoryBytes;
  final double containerNetworkRxBytes;
  final double containerNetworkTxBytes;
  final int liveStatsCount;
  final Map<String, _ServiceLiveMetrics> liveServiceMetrics;
  final Map<String, double> serviceStorageBytes;
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
    required this.memoryUsedBytes,
    required this.memoryTotalBytes,
    required this.storageUsedBytes,
    required this.storageTotalBytes,
  });

  final double cpuPercent;
  final double memoryPercent;
  final double storagePercent;
  final double memoryUsedBytes;
  final double memoryTotalBytes;
  final double storageUsedBytes;
  final double storageTotalBytes;
}

class _ServiceLiveMetrics {
  const _ServiceLiveMetrics({
    required this.cpuPercent,
    required this.memoryUsageBytes,
    required this.memoryLimitBytes,
    required this.networkRxBytes,
    required this.networkTxBytes,
    required this.readAt,
  });

  final double cpuPercent;
  final double memoryUsageBytes;
  final double memoryLimitBytes;
  final double networkRxBytes;
  final double networkTxBytes;
  final String readAt;
}

class _ServaStorageMetrics {
  const _ServaStorageMetrics({
    required this.totalBytes,
    required this.serviceBytes,
  });

  final double totalBytes;
  final Map<String, double> serviceBytes;
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
      : (_listValue(cpuUsage['percpu_usage']).isNotEmpty
            ? _listValue(cpuUsage['percpu_usage']).length.toDouble()
            : 1);

  if (cpuDelta <= 0 || systemDelta <= 0) {
    return 0;
  }

  return (cpuDelta / systemDelta) * cores * 100;
}

double _memoryUsageBytesFromStats(Map<String, dynamic> raw) {
  final memory = _mapValue(raw['memory_stats']);
  return _asDouble(memory['usage']);
}

double _memoryLimitBytesFromStats(Map<String, dynamic> raw) {
  final memory = _mapValue(raw['memory_stats']);
  return _asDouble(memory['limit']);
}

double _networkRxBytesFromStats(Map<String, dynamic> raw) {
  final networks = _mapValue(raw['networks']);
  var total = 0.0;
  for (final value in networks.values) {
    final adapter = _mapValue(value);
    total += _asDouble(adapter['rx_bytes']);
  }
  return total;
}

double _networkTxBytesFromStats(Map<String, dynamic> raw) {
  final networks = _mapValue(raw['networks']);
  var total = 0.0;
  for (final value in networks.values) {
    final adapter = _mapValue(value);
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

double _megabytesToBytes(double value) => value * 1024 * 1024;

String _formatBytes(double bytes) {
  if (bytes <= 0) return '0 B';

  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var value = bytes;
  var unitIndex = 0;

  while (value >= 1024 && unitIndex < units.length - 1) {
    value /= 1024;
    unitIndex++;
  }

  final precision = value >= 100
      ? 0
      : value >= 10
      ? 1
      : 2;
  return '${value.toStringAsFixed(precision)} ${units[unitIndex]}';
}

List<double> _normalizeSeries(List<double> values) {
  if (values.isEmpty) return const [0];
  final maxValue = values.reduce(max);
  if (maxValue <= 0) {
    return List<double>.filled(values.length, 0);
  }
  return values.map((value) => (value / maxValue) * 100).toList();
}

double _dashboardUiScale(double width) {
  if (width >= 1700) return 0.76;
  if (width >= 1500) return 0.82;
  if (width >= 1300) return 0.9;
  if (width >= 1100) return 0.96;
  return 1.0;
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

String? _serviceMountRootFromDefinition(GoServiceDefinition definition) {
  if (definition.mounts.isEmpty) return null;
  final first = definition.mounts.first.source.trim();
  if (first.isEmpty) return null;
  return Directory(first).parent.path;
}

String _psEscape(String value) => value.replaceAll("'", "''");
