part of '../dashboard_screen.dart';

class _HeroPanel extends StatelessWidget {
  const _HeroPanel({
    required this.healthOk,
    required this.runningServices,
    required this.totalServices,
    required this.savedDefinitions,
    required this.lanServices,
    required this.throughputSeries,
    required this.scale,
  });

  final bool healthOk;
  final int runningServices;
  final int totalServices;
  final int savedDefinitions;
  final int lanServices;
  final List<double> throughputSeries;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20 * scale),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF101D36), Color(0xFF0D1527)],
        ),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 10 * scale,
                height: 10 * scale,
                decoration: BoxDecoration(
                  color: healthOk
                      ? const Color(0xFF80ED99)
                      : const Color(0xFFFF7B72),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color:
                          (healthOk
                                  ? const Color(0xFF80ED99)
                                  : const Color(0xFFFF7B72))
                              .withValues(alpha: 0.45),
                      blurRadius: 10,
                    ),
                  ],
                ),
              ),
              SizedBox(width: 8 * scale),
              Text(
                healthOk ? 'System stable' : 'Attention needed',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontSize:
                      (theme.textTheme.titleMedium?.fontSize ?? 16) * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          SizedBox(height: 2 * scale),
          Text(
            healthOk
                ? 'Backend reachable and ready.'
                : 'Docker or the backend needs attention.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: (theme.textTheme.bodySmall?.fontSize ?? 16) * scale,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.74),
            ),
          ),
          SizedBox(height: 6 * scale),
          LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < 850;
              if (compact) {
                return Column(
                  children: [
                    _MiniStatStrip(
                      label: 'Running',
                      value: '$runningServices',
                      accent: const Color(0xFF4CC9F0),
                      scale: scale,
                    ),
                    SizedBox(height: 3 * scale),
                    _MiniStatStrip(
                      label: 'Tracked',
                      value: '$totalServices',
                      accent: const Color(0xFF80ED99),
                      scale: scale,
                    ),
                    SizedBox(height: 3 * scale),
                    _MiniStatStrip(
                      label: 'Saved',
                      value: '$savedDefinitions',
                      accent: const Color(0xFFFFC857),
                      scale: scale,
                    ),
                    SizedBox(height: 3 * scale),
                    _MiniStatStrip(
                      label: 'LAN',
                      value: '$lanServices',
                      accent: const Color(0xFFFF7B72),
                      scale: scale,
                    ),
                  ],
                );
              }

              return Row(
                children: [
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'Running',
                      value: '$runningServices',
                      accent: const Color(0xFF4CC9F0),
                      scale: scale,
                    ),
                  ),
                  SizedBox(width: 3 * scale),
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'Tracked',
                      value: '$totalServices',
                      accent: const Color(0xFF80ED99),
                      scale: scale,
                    ),
                  ),
                  SizedBox(width: 3 * scale),
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'Saved',
                      value: '$savedDefinitions',
                      accent: const Color(0xFFFFC857),
                      scale: scale,
                    ),
                  ),
                  SizedBox(width: 3 * scale),
                  Expanded(
                    child: _MiniStatStrip(
                      label: 'LAN',
                      value: '$lanServices',
                      accent: const Color(0xFFFF7B72),
                      scale: scale,
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

class _MiniStatStrip extends StatelessWidget {
  const _MiniStatStrip({
    required this.label,
    required this.value,
    required this.accent,
    required this.scale,
  });

  final String label;
  final String value;
  final Color accent;
  final double scale;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: 10 * scale,
        vertical: 8 * scale,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(14 * scale),
      ),
      child: Row(
        children: [
          Container(
            width: 8 * scale,
            height: 8 * scale,
            decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
          ),
          SizedBox(width: 8 * scale),
          Expanded(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                fontSize:
                    (Theme.of(context).textTheme.bodyMedium?.fontSize ?? 17) *
                    scale,
              ),
            ),
          ),
          Text(
            value,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontSize:
                  (Theme.of(context).textTheme.titleSmall?.fontSize ?? 17) *
                  scale,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
