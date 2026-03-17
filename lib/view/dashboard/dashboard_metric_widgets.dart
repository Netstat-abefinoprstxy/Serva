part of '../dashboard_screen.dart';

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.caption,
    required this.color,
    required this.icon,
    required this.series,
    required this.graphTick,
    required this.scale,
    this.footer,
  });

  final String label;
  final String value;
  final String caption;
  final Color color;
  final IconData icon;
  final List<double> series;
  final int graphTick;
  final double scale;
  final String? footer;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF0F1728).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(8 * scale),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14 * scale),
                ),
                child: Icon(icon, color: color),
              ),
              SizedBox(width: 8 * scale),
              Expanded(
                child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.right,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontSize:
                        (theme.textTheme.labelMedium?.fontSize ?? 16) * scale,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          SizedBox(
            height: 86 * scale,
            width: double.infinity,
            child: CustomPaint(
              painter: _HistoryBarsPainter(
                values: series,
                color: color,
                tick: graphTick,
              ),
            ),
          ),
          SizedBox(height: 8 * scale),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontSize:
                  (theme.textTheme.headlineMedium?.fontSize ?? 28) * scale,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
          SizedBox(height: 2 * scale),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 18) * scale,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          if (footer != null) ...[
            SizedBox(height: 2 * scale),
            Text(
              footer!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 17) * scale,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.56),
              ),
            ),
          ],
          SizedBox(height: 4 * scale),
        ],
      ),
    );
  }
}

class _InlineMetric extends StatelessWidget {
  const _InlineMetric({
    required this.label,
    required this.value,
    required this.scale,
  });

  final String label;
  final String value;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: theme.textTheme.labelSmall?.copyWith(
            fontSize: (theme.textTheme.labelSmall?.fontSize ?? 16) * scale,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.58),
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 2 * scale),
        Text(
          value,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontSize: (theme.textTheme.bodyMedium?.fontSize ?? 17) * scale,
            fontWeight: FontWeight.w600,
          ),
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }
}
