part of '../homescreen.dart';

Future<void> _showDefinitionDetailsSheet(BuildContext context, GoServiceDefinition definition) async {
  final bloc = context.read<MainBloc>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.75,
      child: _DefinitionDetailsSheet(definition: definition, bloc: bloc),
    ),
  );
}

class _DefinitionDetailsSheet extends StatelessWidget {
  const _DefinitionDetailsSheet({required this.definition, required this.bloc});

  final GoServiceDefinition definition;
  final MainBloc bloc;

  Future<void> _confirmDelete(BuildContext context) async {
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete saved definition?'),
        content: const Text(
          'You can remove just the saved definition, or also delete any persistent data marked as managed by Serva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop('definition'),
            child: const Text('Delete definition'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop('definition+data'),
            child: const Text('Delete with data'),
          ),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    Navigator.of(context).pop();
    bloc.add(
      MainDeleteDefinitionRequested(
        id: definition.id,
        deleteData: choice == 'definition+data',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(definition.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(definition.image, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  bloc.add(MainRecreateRequested(id: definition.id));
                },
                icon: const Icon(Icons.restore),
                label: const Text('Recreate'),
              ),
              const SizedBox(width: 8),
              FilledButton.tonalIcon(
                onPressed: () => _confirmDelete(context),
                icon: const Icon(Icons.delete_outline),
                label: const Text('Delete'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView(
              children: [
                _DetailSection(
                  title: 'Definition',
                  child: Column(
                    children: [
                      _DetailRow(label: 'ID', value: definition.id),
                      _DetailRow(label: 'Port', value: definition.containerPort.toString()),
                      _DetailRow(label: 'Protocol', value: definition.serviceProto),
                      _DetailRow(label: 'LAN', value: definition.lanEnabled ? 'enabled' : 'disabled'),
                      _DetailRow(
                        label: 'Current container',
                        value: definition.currentContainerId.isEmpty ? 'not deployed' : _shortId(definition.currentContainerId),
                      ),
                      _DetailRow(
                        label: 'Last host port',
                        value: definition.lastKnownHostPort == 0 ? 'n/a' : definition.lastKnownHostPort.toString(),
                      ),
                      _DetailRow(label: 'Created', value: definition.createdAt),
                      _DetailRow(label: 'Updated', value: definition.updatedAt),
                    ],
                  ),
                ),
                _DetailSection(
                  title: 'Persistent Mounts',
                  child: definition.mounts.isEmpty
                      ? const Text('No persistent mounts configured yet.')
                      : Column(
                          children: definition.mounts
                              .map(
                                (mount) => _DetailRow(
                                  label: mount.target,
                                  value:
                                      '${mount.source} (${mount.type}${mount.readOnly ? ', read-only' : ''}${mount.managed ? ', managed' : ''})',
                                  trailing: mount.type.toLowerCase() == 'bind'
                                      ? IconButton(
                                          tooltip: 'Open folder',
                                          onPressed: () => _openDirectory(context, mount.source),
                                          icon: const Icon(Icons.folder_open),
                                        )
                                      : null,
                                ),
                              )
                              .toList(),
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
