part of '../services_overview_screen.dart';

class _InactiveServiceTile extends StatelessWidget {
  const _InactiveServiceTile({required this.definition});

  final GoServiceDefinition definition;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bloc = context.read<MainBloc>();
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(definition.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(color: const Color(0xFFFFC857).withValues(alpha: 0.14), borderRadius: BorderRadius.circular(999)),
                child: Text('SAVED', style: theme.textTheme.labelSmall?.copyWith(color: const Color(0xFFFFC857), fontWeight: FontWeight.w800, letterSpacing: 0.8)),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(definition.image, maxLines: 1, overflow: TextOverflow.ellipsis, style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.66))),
          const Spacer(),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _CompactActionChip(label: 'Restore', icon: Icons.restore_rounded, color: const Color(0xFF80ED99), onTap: () => bloc.add(MainRecreateRequested(id: definition.id))),
              _CompactActionChip(label: 'Delete', icon: Icons.delete_outline_rounded, color: const Color(0xFFFF7B72), onTap: () => _confirmDelete(context, bloc)),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDelete(BuildContext context, MainBloc bloc) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved service?'),
        content: Text('Choose whether to remove only the saved definition for "${definition.name}" or also delete its managed persistent data.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          OutlinedButton(onPressed: () => Navigator.of(context).pop('definition'), child: const Text('Delete definition')),
          FilledButton(onPressed: () => Navigator.of(context).pop('definition+data'), child: const Text('Delete with data')),
        ],
      ),
    );
    if (choice != null && context.mounted) {
      bloc.add(MainDeleteDefinitionRequested(id: definition.id, deleteData: choice == 'definition+data'));
    }
  }
}
