part of '../dashboard_screen.dart';

class _QuickLinksPanel extends StatelessWidget {
  const _QuickLinksPanel({
    required this.services,
    required this.scale,
  });

  final List<GoService> services;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final linkedServices = services
        .where(
          (service) =>
              isTailscaleService(service) ||
              service.localUrl.trim().isNotEmpty ||
              service.lanUrl.trim().isNotEmpty,
        )
        .toList();

    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.88),
        borderRadius: BorderRadius.circular(20 * scale),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Quick Links',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: (theme.textTheme.titleLarge?.fontSize ?? 20) * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 1 * scale),
          Text(
            'Jump straight into every service web UI from one place.',
            style: theme.textTheme.bodySmall?.copyWith(
              fontSize: (theme.textTheme.bodySmall?.fontSize ?? 14) * scale,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
            ),
          ),
          SizedBox(height: 6 * scale),
          if (linkedServices.isEmpty)
            Container(
              padding: EdgeInsets.all(8 * scale),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(16 * scale),
              ),
              child: const Text('No service links available yet.'),
            )
          else
            Wrap(
              spacing: 6 * scale,
              runSpacing: 6 * scale,
              children: [
                for (final service in linkedServices)
                  _QuickLinkTile(service: service, scale: scale),
              ],
            ),
        ],
      ),
    );
  }
}

class _QuickLinkTile extends StatelessWidget {
  const _QuickLinkTile({
    required this.service,
    required this.scale,
  });

  final GoService service;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasLocal = service.localUrl.trim().isNotEmpty;
    final hasLan = service.lanUrl.trim().isNotEmpty;
    final accent = service.state.toLowerCase() == 'running'
        ? const Color(0xFF80ED99)
        : const Color(0xFFFFC857);

    return Container(
      padding: EdgeInsets.symmetric(horizontal: 8 * scale, vertical: 6 * scale),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.symmetric(horizontal: 6 * scale, vertical: 3 * scale),
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              service.state.toUpperCase(),
              style: theme.textTheme.labelSmall?.copyWith(
                color: accent,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.5,
              ),
            ),
          ),
          SizedBox(width: 7 * scale),
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: 170 * scale),
            child: Text(
              service.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelLarge?.copyWith(
                fontSize: (theme.textTheme.labelLarge?.fontSize ?? 14) * scale,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          SizedBox(width: 8 * scale),
          if (hasLocal)
            _MiniLinkChip(
              label: 'Local',
              icon: Icons.open_in_new_rounded,
              onTap: () => _openUrl(context, service.localUrl),
            ),
          if (hasLocal && isTailscaleService(service)) SizedBox(width: 4 * scale),
          if (isTailscaleService(service))
            _MiniLinkChip(
              label: 'Auth',
              icon: Icons.login_rounded,
              onTap: () => openTailscaleAuthFlow(context, service),
            ),
          if (hasLocal && hasLan) SizedBox(width: 4 * scale),
          if (hasLan)
            _MiniLinkChip(
              label: 'LAN',
              icon: Icons.wifi_rounded,
              onTap: () => _openUrl(context, service.lanUrl),
            ),
        ],
      ),
    );
  }
}

class _MiniLinkChip extends StatelessWidget {
  const _MiniLinkChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Ink(
          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 5),
          decoration: BoxDecoration(
            color: theme.colorScheme.primary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: theme.colorScheme.primary.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: theme.colorScheme.primary),
              const SizedBox(width: 3),
              Text(
                label,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
