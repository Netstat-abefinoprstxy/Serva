part of '../homescreen.dart';

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final GoService service;

  bool get _isRunning => service.state.toLowerCase() == 'running';
  bool get _isLanExposed => service.lanEnabled;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MainBloc>();
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(
        child: Icon(_isRunning ? Icons.play_arrow : Icons.stop),
      ),
      onTap: () => showServiceDetailsSheet(context, service),
      title: Text(service.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${service.image} • ${service.status}'),
          if (service.localUrl.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                service.localUrl,
                style: theme.textTheme.bodySmall,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          if (service.lanEnabled && service.lanUrl.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                service.lanUrl,
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.primary),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
      ),
      isThreeLine: true,
      trailing: Wrap(
        spacing: 4,
        children: [
          if (service.localUrl.trim().isNotEmpty)
            IconButton(
              tooltip: 'Open',
              onPressed: () => _openUrl(context, service.localUrl),
              icon: const Icon(Icons.open_in_new),
            ),
          if (_isRunning)
            IconButton(
              tooltip: _isLanExposed ? 'Disable LAN access' : 'Expose to LAN',
              onPressed: () => bloc.add(MainExposeLanRequested(id: service.id, enabled: !_isLanExposed)),
              icon: Icon(
                Icons.wifi,
                color: _isLanExposed ? theme.colorScheme.primary : null,
              ),
            ),
          if (!_isRunning)
            IconButton(
              tooltip: 'Start',
              onPressed: () => bloc.add(MainStartRequested(id: service.id)),
              icon: const Icon(Icons.play_arrow),
            )
          else
            IconButton(
              tooltip: 'Stop',
              onPressed: () => bloc.add(MainStopRequested(id: service.id)),
              icon: const Icon(Icons.stop),
            ),
          IconButton(
            tooltip: 'Details',
            onPressed: () => showServiceDetailsSheet(context, service),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}

class _SavedDefinitionTile extends StatelessWidget {
  const _SavedDefinitionTile({required this.definition});

  final GoServiceDefinition definition;

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MainBloc>();

    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.save_outlined)),
      title: Text(definition.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${definition.image} • saved definition'),
          if (definition.mounts.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '${definition.mounts.length} persistent mount${definition.mounts.length == 1 ? '' : 's'}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
        ],
      ),
      isThreeLine: definition.mounts.isNotEmpty,
      trailing: Wrap(
        spacing: 4,
        children: [
          IconButton(
            tooltip: 'Recreate',
            onPressed: () => bloc.add(MainRecreateRequested(id: definition.id)),
            icon: const Icon(Icons.restore),
          ),
          IconButton(
            tooltip: 'Details',
            onPressed: () => _showDefinitionDetailsSheet(context, definition),
            icon: const Icon(Icons.tune),
          ),
        ],
      ),
    );
  }
}
