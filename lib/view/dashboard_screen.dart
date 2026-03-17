import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/api/sovereign_api.dart';
import 'package:serva/bloc/main_bloc.dart';
import 'package:serva/bloc/main_event.dart';
import 'package:serva/bloc/main_state.dart';
import 'package:url_launcher/url_launcher.dart';

import 'service_details_sheet.dart';

part 'dashboard/dashboard_action_widgets.dart';
part 'dashboard/dashboard_models.dart';
part 'dashboard/dashboard_metric_widgets.dart';
part 'dashboard/dashboard_header_widgets.dart';
part 'dashboard/dashboard_activity_widgets.dart';
part 'dashboard/dashboard_support_banner.dart';
part 'dashboard/dashboard_mission_panel.dart';
part 'dashboard/dashboard_painters.dart';
part 'dashboard/dashboard_service_containers.dart';
part 'dashboard/dashboard_service_command_tile.dart';
part 'dashboard/dashboard_inactive_service_tile.dart';
part 'dashboard/dashboard_utils.dart';
part 'dashboard/dashboard_logic.dart';

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

              final crossAxisCount = width >= 1000 ? 4 : 2;

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
          SizedBox(height: 8 * uiScale),
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
}
