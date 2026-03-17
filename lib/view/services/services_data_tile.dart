part of '../services_overview_screen.dart';

class _DataTile extends StatelessWidget {
  const _DataTile({
    required this.entry,
    required this.onChanged,
  });

  final _DataEntry entry;
  final VoidCallback onChanged;

  String? get _miscRoot {
    for (final mount in entry.mounts) {
      if (mount.type.trim().toLowerCase() == 'bind' && mount.target.trim() == '/misc') {
        final source = mount.source.trim();
        if (source.isNotEmpty) return source;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<MainBloc>();
    final statusColor = entry.isGlobalRoot
        ? const Color(0xFF4CC9F0)
        : entry.isOrphaned
            ? const Color(0xFFFF7B72)
            : entry.isDeployed
                ? const Color(0xFF80ED99)
                : const Color(0xFFFFC857);

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.folder_open_rounded, color: statusColor, size: 18),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(entry.serviceName, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                    const SizedBox(height: 2),
                    Text(entry.image, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.66))),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _ServiceMeta(label: 'Status', value: entry.isGlobalRoot ? 'Serva local' : entry.isOrphaned ? 'Orphaned data' : entry.isDeployed ? 'Connected' : 'Saved only'),
          const SizedBox(height: 8),
          _ServiceMeta(label: 'Size', value: _formatBytes(entry.sizeBytes)),
          const SizedBox(height: 8),
          _ServiceMeta(label: 'Root folder', value: entry.rootPath),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ...entry.mounts.map((mount) => _pill(theme, mount.target)),
              ...entry.miscSubfolders.map((folder) => _pill(theme, folder, highlighted: true)),
            ],
          ),
          const Spacer(),
          if (_miscRoot != null) ...[
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                _CompactActionChip(label: 'New folder', icon: Icons.create_new_folder_rounded, color: const Color(0xFF80ED99), onTap: () => _createMiscSubfolder(context, bloc, _miscRoot!)),
                _CompactActionChip(label: 'Delete folder', icon: Icons.folder_delete_rounded, color: const Color(0xFFFFC857), onTap: () => _deleteMiscSubfolder(context, bloc, _miscRoot!)),
              ],
            ),
            const SizedBox(height: 6),
          ],
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CompactActionChip(label: 'Open folder', icon: Icons.folder_open_rounded, color: const Color(0xFF4CC9F0), onTap: () => _openDirectory(context, entry.rootPath)),
              _CompactActionChip(label: 'Wipe', icon: Icons.cleaning_services_rounded, color: const Color(0xFFFFC857), onTap: () => _confirmWipe(context, bloc)),
              _CompactActionChip(label: 'Delete', icon: Icons.delete_forever_rounded, color: const Color(0xFFFF7B72), onTap: () => _confirmDelete(context, bloc)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _pill(ThemeData theme, String label, {bool highlighted = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlighted ? const Color(0xFF4CC9F0).withValues(alpha: 0.12) : Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(999),
        border: highlighted ? Border.all(color: const Color(0xFF4CC9F0).withValues(alpha: 0.18)) : null,
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          color: highlighted ? const Color(0xFF9EDFF5) : theme.colorScheme.onSurface.withValues(alpha: 0.78),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
