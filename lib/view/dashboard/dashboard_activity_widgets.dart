part of '../dashboard_screen.dart';

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
