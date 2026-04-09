part of '../dashboard_screen.dart';

bool _looksLikeBackendUnavailable(String? message) {
  if (message == null || message.trim().isEmpty) {
    return false;
  }

  final normalized = message.toLowerCase();
  return normalized.contains('connection refused') ||
      normalized.contains('actively refused') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('socketexception') ||
      normalized.contains('health check failed') && !normalized.contains('docker unavailable');
}

bool _looksLikeDockerUnavailable(String? message) {
  if (message == null || message.trim().isEmpty) {
    return false;
  }

  final normalized = message.toLowerCase();
  return normalized.contains('docker') ||
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

  if (cpuDelta <= 0 || systemDelta <= 0) {
    return 0;
  }

  return ((cpuDelta / systemDelta) * 100).clamp(0, 100).toDouble();
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
