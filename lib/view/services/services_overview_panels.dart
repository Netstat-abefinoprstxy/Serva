part of '../services_overview_screen.dart';

class _LegacyModeCard extends StatelessWidget {
  const _LegacyModeCard({
    required this.legacyModeEnabled,
    required this.onChanged,
  });

  final bool legacyModeEnabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
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
                Text('Legacy mode', style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
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
          Switch(value: legacyModeEnabled, onChanged: onChanged),
        ],
      ),
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
            style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
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
