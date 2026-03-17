part of '../dashboard_screen.dart';

extension _DashboardScreenStateLogic on _DashboardScreenState {
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
}

int _boundedValue(int value, int min, int max) => value.clamp(min, max);

List<double> _buildSeriesFromSeed(int seed, int points, int amplitude) {
  final random = Random(seed);
  return List<double>.generate(points, (index) {
    final base = 42 + sin((index + seed) / 2.2) * amplitude;
    final noise = random.nextDouble() * 12 - 6;
    return (base + noise).clamp(8, 96).toDouble();
  });
}
