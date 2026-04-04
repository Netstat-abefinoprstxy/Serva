part of '../services_overview_screen.dart';

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
  if (cpuDelta <= 0 || systemDelta <= 0) return 0;
  return ((cpuDelta / systemDelta) * 100).clamp(0, 100).toDouble();
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

String _servaLocalDataPath() => '${_servaManagedBasePath()}${Platform.pathSeparator}serva-local';

String? _serviceMountRootFromDefinition(GoServiceDefinition definition) {
  if (definition.mounts.isEmpty) return null;
  final first = definition.mounts.first.source.trim();
  if (first.isEmpty) return null;
  return Directory(first).parent.path;
}

String? _dataRootFromDefinition(GoServiceDefinition definition) {
  final managedBindMounts = definition.mounts.where((mount) => mount.managed && mount.type.trim().toLowerCase() == 'bind').toList();
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
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open service link')));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open folder: $error')));
  }
}
