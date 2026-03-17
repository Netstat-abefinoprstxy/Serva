part of '../dashboard_screen.dart';

class _DashboardSupportBanner extends StatelessWidget {
  const _DashboardSupportBanner({required this.message, required this.scale});

  final String message;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final virtualizationIssue = _looksLikeVirtualizationIssue(message);
    final dockerUnavailable = _looksLikeDockerUnavailable(message);
    final accent = virtualizationIssue
        ? const Color(0xFFFFC857)
        : const Color(0xFF4CC9F0);

    return Container(
      padding: EdgeInsets.all(8 * scale),
      decoration: BoxDecoration(
        color: const Color(0xFF0D1526).withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(16 * scale),
        border: Border.all(color: accent.withValues(alpha: 0.28)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            virtualizationIssue ? Icons.memory_rounded : Icons.download_rounded,
            color: accent,
          ),
          SizedBox(width: 10 * scale),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  virtualizationIssue
                      ? 'Virtualization may be required'
                      : 'Docker Desktop may be required',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontSize:
                        (theme.textTheme.titleSmall?.fontSize ?? 17) * scale,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 4 * scale),
                Text(
                  virtualizationIssue
                      ? 'Docker Desktop needs virtualization enabled to run. You may need to enable virtualization in Windows and in your BIOS/UEFI settings.'
                      : 'Serva could not reach Docker Desktop. Install it or make sure it is running, then refresh the dashboard.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontSize:
                        (theme.textTheme.bodySmall?.fontSize ?? 16) * scale,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.76),
                  ),
                ),
                if (message.trim().isNotEmpty) ...[
                  SizedBox(height: 4 * scale),
                  Text(
                    message,
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontSize:
                          (theme.textTheme.bodySmall?.fontSize ?? 16) * scale,
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.56,
                      ),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
                SizedBox(height: 8 * scale),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    if (dockerUnavailable)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openUrl(context, _dockerDesktopStoreUrl),
                        icon: const Icon(Icons.download_rounded),
                        label: const Text('Install Docker Desktop'),
                      ),
                    if (virtualizationIssue)
                      OutlinedButton.icon(
                        onPressed: () =>
                            _openUrl(context, _virtualizationHelpUrl),
                        icon: const Icon(Icons.memory_rounded),
                        label: const Text('Virtualization Help'),
                      ),
                    OutlinedButton.icon(
                      onPressed: () => context.read<MainBloc>().add(
                        const MainLoadRequested(),
                      ),
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Refresh'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
