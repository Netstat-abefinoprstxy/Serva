part of '../services_overview_screen.dart';

extension _ServicesOverviewMetrics on _ServicesOverviewScreenState {
  void _refreshLocalMetrics() {
    if (!mounted) return;
    setState(() {
      _metricsFuture = _loadMetrics();
    });
  }

  Future<_ServicesMetrics> _loadMetrics() async {
    final services = widget.state.services;
    final definitions = widget.state.definitions;
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

    final baseDataEntries = dataEntriesByRoot.values.toList()
      ..sort((a, b) {
        if (a.isGlobalRoot != b.isGlobalRoot) return a.isGlobalRoot ? -1 : 1;
        if (a.isOrphaned != b.isOrphaned) return a.isOrphaned ? 1 : -1;
        return a.serviceName.toLowerCase().compareTo(b.serviceName.toLowerCase());
      });

    try {
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
      final dataFolderSizes = await _loadFolderSizes(
        baseDataEntries.map((entry) => entry.rootPath).toSet().toList(),
      );
      final miscSubfolders = _loadMiscSubfolders(baseDataEntries);

      return _ServicesMetrics(
        liveMetrics: liveMetrics,
        serviceStorageBytes: serviceStorageBytes,
        serviceMountRoots: serviceMountRoots,
        dataEntries: baseDataEntries
            .map(
              (entry) => entry.copyWith(
                sizeBytes: dataFolderSizes[entry.rootPath] ?? 0,
                miscSubfolders: miscSubfolders[entry.rootPath] ?? const [],
              ),
            )
            .toList(),
      );
    } catch (_) {
      return _ServicesMetrics(
        liveMetrics: const {},
        serviceStorageBytes: const {},
        serviceMountRoots: serviceMountRoots,
        dataEntries: baseDataEntries,
      );
    }
  }
}
