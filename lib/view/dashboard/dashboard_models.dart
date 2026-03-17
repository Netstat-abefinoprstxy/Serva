part of '../dashboard_screen.dart';

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
