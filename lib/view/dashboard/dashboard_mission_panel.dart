part of '../dashboard_screen.dart';

class _MissionPanel extends StatelessWidget {
  const _MissionPanel({
    required this.healthOk,
    required this.lastMessage,
    required this.savedDefinitions,
    required this.services,
    required this.scale,
  });

  final bool healthOk;
  final String? lastMessage;
  final int savedDefinitions;
  final int services;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dockerUnavailable = _looksLikeDockerUnavailable(lastMessage);
    final virtualizationIssue = _looksLikeVirtualizationIssue(lastMessage);
    final dockerConnected = healthOk && !dockerUnavailable;
    final virtualizationReady = !virtualizationIssue;
    final controlPlaneReady = healthOk;
    final readinessChecks = [
      dockerConnected,
      virtualizationReady,
      controlPlaneReady,
    ];
    final readinessScore =
        ((readinessChecks.where((check) => check).length /
                    readinessChecks.length) *
                100)
            .round();

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
            'Mission profile',
            style: theme.textTheme.titleLarge?.copyWith(
              fontSize: (theme.textTheme.titleLarge?.fontSize ?? 26) * scale,
              fontWeight: FontWeight.w700,
            ),
          ),
          SizedBox(height: 6 * scale),
          Center(
            child: SizedBox(
              width: 156 * scale,
              height: 156 * scale,
              child: CustomPaint(
                painter: _GaugePainter(value: readinessScore / 100),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '$readinessScore%',
                        style: theme.textTheme.headlineMedium?.copyWith(
                          fontSize:
                              (theme.textTheme.headlineMedium?.fontSize ?? 40) *
                              scale,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      SizedBox(height: 4 * scale),
                      Text(
                        'Readiness',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontSize:
                              (theme.textTheme.bodyMedium?.fontSize ?? 20) *
                              scale,
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.72,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: 6 * scale),
          _ChecklistItem(
            title: dockerConnected ? 'Docker connected' : 'Docker unavailable',
            subtitle: dockerConnected
                ? 'Docker Desktop is reachable from Serva.'
                : 'Install or start Docker Desktop so Serva can manage services.',
            success: dockerConnected,
            scale: scale,
          ),
          SizedBox(height: 4 * scale),
          _ChecklistItem(
            title: virtualizationReady
                ? 'Virtualization ready'
                : 'Virtualization required',
            subtitle: virtualizationReady
                ? 'Hardware virtualization looks ready for Docker Desktop.'
                : 'You may need to enable virtualization in Windows and BIOS/UEFI.',
            success: virtualizationReady,
            scale: scale,
          ),
          SizedBox(height: 4 * scale),
          _ChecklistItem(
            title: controlPlaneReady
                ? 'Control plane reachable'
                : 'Control plane degraded',
            subtitle: controlPlaneReady
                ? 'Serva can talk to the local daemon.'
                : 'Backend or Docker needs attention before services can be managed.',
            success: controlPlaneReady,
            scale: scale,
          ),
          SizedBox(height: 4 * scale),
          _ChecklistItem(
            title: '$services services, $savedDefinitions saved',
            subtitle:
                'Inventory count for live services and saved recovery definitions.',
            success: services > 0 || savedDefinitions > 0,
            scale: scale,
          ),
        ],
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.title,
    required this.subtitle,
    required this.success,
    required this.scale,
  });

  final String title;
  final String subtitle;
  final bool success;
  final double scale;

  @override
  Widget build(BuildContext context) {
    final color = success ? const Color(0xFF80ED99) : const Color(0xFFFFC857);
    final theme = Theme.of(context);

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: 2 * scale),
          child: Icon(
            success ? Icons.verified_rounded : Icons.timelapse_rounded,
            color: color,
            size: 20 * scale,
          ),
        ),
        SizedBox(width: 10 * scale),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontSize:
                      (theme.textTheme.titleLarge?.fontSize ?? 22) * scale,
                  fontWeight: FontWeight.w700,
                ),
              ),
              SizedBox(height: 2 * scale),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize:
                      (theme.textTheme.bodyLarge?.fontSize ?? 19) * scale,
                  fontWeight: FontWeight.w500,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
