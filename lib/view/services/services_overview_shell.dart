part of '../services_overview_screen.dart';

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
            _LegacyModeCard(
              legacyModeEnabled: widget.legacyModeEnabled,
              onChanged: widget.onLegacyModeChanged,
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
