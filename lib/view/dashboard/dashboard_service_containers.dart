part of '../dashboard_screen.dart';

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
