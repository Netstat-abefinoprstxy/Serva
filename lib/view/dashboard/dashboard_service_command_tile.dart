part of '../dashboard_screen.dart';

class _ServiceCommandTile extends StatelessWidget {
  const _ServiceCommandTile({
    required this.service,
    this.liveMetrics,
    this.storageBytes,
  });

  final GoService service;
  final _ServiceLiveMetrics? liveMetrics;
  final double? storageBytes;

  bool get _isRunning => service.state.toLowerCase() == 'running';

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<MainBloc>();
    final accent = _isRunning
        ? const Color(0xFF80ED99)
        : const Color(0xFFFFC857);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            const Color(0xFF17233C),
            Color.alphaBlend(
              accent.withValues(alpha: 0.12),
              const Color(0xFF101A2D),
            ),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      service.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      service.image,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  _isRunning ? 'RUNNING' : 'STOPPED',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: accent,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _ActionChip(
                label: service.localUrl.trim().isNotEmpty ? 'Open' : 'Manage',
                icon: service.localUrl.trim().isNotEmpty
                    ? Icons.open_in_new_rounded
                    : Icons.tune_rounded,
                onTap: () {
                  if (service.localUrl.trim().isNotEmpty) {
                    _openUrl(context, service.localUrl);
                  }
                },
              ),
              _ActionChip(
                label: 'Details',
                icon: Icons.tune_rounded,
                onTap: () => showServiceDetailsSheet(context, service),
              ),
              _ActionChip(
                label: _isRunning ? 'Pause' : 'Start',
                icon: _isRunning
                    ? Icons.pause_circle_outline_rounded
                    : Icons.play_circle_outline_rounded,
                onTap: () {
                  if (_isRunning) {
                    bloc.add(MainStopRequested(id: service.id));
                  } else {
                    bloc.add(MainStartRequested(id: service.id));
                  }
                },
              ),
              _ActionChip(
                label: 'Restart',
                icon: Icons.restart_alt_rounded,
                onTap: () => bloc.add(MainRestartRequested(id: service.id)),
              ),
              _ActionChip(
                label: service.lanEnabled ? 'LAN On' : 'LAN Off',
                icon: Icons.wifi_tethering_rounded,
                onTap: () => bloc.add(
                  MainExposeLanRequested(
                    id: service.id,
                    enabled: !service.lanEnabled,
                  ),
                ),
              ),
              _ActionChip(
                label: 'Remove',
                icon: Icons.delete_outline_rounded,
                destructive: true,
                onTap: () => _confirmRemove(context, bloc),
              ),
            ],
          ),
          const Spacer(),
          const SizedBox(height: 4),
          if (liveMetrics != null) ...[
            Wrap(
              spacing: 12,
              runSpacing: 4,
              children: [
                _ServiceMeta(
                  label: 'CPU',
                  value: '${liveMetrics!.cpuPercent.toStringAsFixed(1)}%',
                ),
                _ServiceMeta(
                  label: 'RAM',
                  value: liveMetrics!.memoryLimitBytes > 0
                      ? '${_formatBytes(liveMetrics!.memoryUsageBytes)} / ${_formatBytes(liveMetrics!.memoryLimitBytes)}'
                      : _formatBytes(liveMetrics!.memoryUsageBytes),
                ),
                _ServiceMeta(
                  label: 'Net',
                  value:
                      '${_formatBytes(liveMetrics!.networkRxBytes)} rx / ${_formatBytes(liveMetrics!.networkTxBytes)} tx',
                ),
                _ServiceMeta(
                  label: 'Data',
                  value: _formatBytes(storageBytes ?? 0),
                ),
              ],
            ),
            const SizedBox(height: 4),
          ],
          Row(
            children: [
              _ServiceMeta(
                label: 'Port',
                value: service.port > 0 ? '${service.port}' : 'none',
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ServiceMeta(label: 'Status', value: service.status),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context, MainBloc bloc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove service?'),
        content: Text(
          'This will remove "${service.name}" from the current deployment.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      bloc.add(MainRemoveRequested(id: service.id));
    }
  }
}
