part of '../homescreen.dart';

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state, required this.onCreateService});

  final MainLoaded state;
  final VoidCallback onCreateService;

  @override
  Widget build(BuildContext context) {
    final services = state.services;
    final activeDefinitionIds = services.map((service) => service.name).toSet();
    final savedDefinitions = state.definitions
        .where((definition) => !activeDefinitionIds.contains(definition.name))
        .toList();

    return Column(
      children: [
        _Header(healthOk: state.healthOk, lastMessage: state.lastMessage),
        const Divider(height: 1),
        Expanded(
          child: services.isEmpty && savedDefinitions.isEmpty
              ? _EmptyServices(onCreate: onCreateService)
              : ListView(
                  children: [
                    if (services.isNotEmpty) ...[
                      const _SectionTitle(title: 'Live Services'),
                      for (final service in services) ...[
                        _ServiceTile(service: service),
                        const Divider(height: 1),
                      ],
                    ],
                    if (savedDefinitions.isNotEmpty) ...[
                      const _SectionTitle(title: 'Saved Definitions'),
                      for (final definition in savedDefinitions) ...[
                        _SavedDefinitionTile(definition: definition),
                        const Divider(height: 1),
                      ],
                    ],
                  ],
                ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium,
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.healthOk, this.lastMessage});

  final bool healthOk;
  final String? lastMessage;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dockerUnavailable = _looksLikeDockerUnavailable(lastMessage);
    final virtualizationIssue = _looksLikeVirtualizationIssue(lastMessage);

    return Padding(
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Icon(
            healthOk ? Icons.check_circle : Icons.warning_amber_rounded,
            color: healthOk ? theme.colorScheme.primary : theme.colorScheme.error,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  healthOk
                      ? 'Daemon connected'
                      : virtualizationIssue
                      ? 'Virtualization required'
                      : dockerUnavailable
                      ? 'Docker Desktop required'
                      : 'Daemon not reachable',
                  style: theme.textTheme.titleSmall,
                ),
                if (lastMessage != null && lastMessage!.trim().isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      lastMessage!,
                      style: theme.textTheme.bodySmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                if (dockerUnavailable)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: OutlinedButton.icon(
                        onPressed: () => _openUrl(context, _dockerDesktopStoreUrl),
                        icon: const Icon(Icons.download),
                        label: const Text('Install Docker Desktop'),
                      ),
                    ),
                  ),
                if (virtualizationIssue)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'You may need to enable virtualization inside your BIOS/UEFI before Docker Desktop can start.',
                          style: theme.textTheme.bodySmall,
                        ),
                        const SizedBox(height: 8),
                        OutlinedButton.icon(
                          onPressed: () => _openUrl(context, _virtualizationHelpUrl),
                          icon: const Icon(Icons.memory),
                          label: const Text('Virtualization Help'),
                        ),
                      ],
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

class _EmptyServices extends StatelessWidget {
  const _EmptyServices({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.cloud_outlined, size: 48),
            const SizedBox(height: 12),
            const Text(
              'No services yet',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Create your first service to confirm everything is wired up.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreate,
              icon: const Icon(Icons.add),
              label: const Text('Create service'),
            ),
          ],
        ),
      ),
    );
  }
}
