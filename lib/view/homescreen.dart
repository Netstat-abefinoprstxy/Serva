import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sovereign/api/go_models.dart';

import '../bloc/main_bloc.dart';
import '../bloc/main_event.dart';
import '../bloc/main_state.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Sovereign'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<MainBloc>().add(const MainLoadRequested()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<MainBloc, MainState>(
        builder: (context, state) {
          if (state is MainInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MainLoading) {
            return _LoadingView(message: state.message);
          }

          if (state is MainError) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<MainBloc>().add(const MainLoadRequested()),
            );
          }

          if (state is MainLoaded) {
            return _LoadedView(state: state);
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.read<MainBloc>().add(const MainCreateTestRequested()),
        icon: const Icon(Icons.add),
        label: const Text('Create test service'),
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [const CircularProgressIndicator(), const SizedBox(height: 12), Text(message ?? 'Working…')],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.state});

  final MainLoaded state;

  @override
  Widget build(BuildContext context) {
    final services = state.services;

    return Column(
      children: [
        _Header(healthOk: state.healthOk, lastMessage: state.lastMessage),
        const Divider(height: 1),
        Expanded(
          child: services.isEmpty
              ? _EmptyServices(onCreateTest: () => context.read<MainBloc>().add(const MainCreateTestRequested()))
              : ListView.separated(
                  itemCount: services.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final s = services[index];
                    return _ServiceTile(service: s);
                  },
                ),
        ),
      ],
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
                Text(healthOk ? 'Daemon connected' : 'Daemon not reachable', style: theme.textTheme.titleSmall),
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
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyServices extends StatelessWidget {
  const _EmptyServices({required this.onCreateTest});

  final VoidCallback onCreateTest;

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
            const Text('No services yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Create a test service to confirm everything is wired up.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onCreateTest,
              icon: const Icon(Icons.add),
              label: const Text('Create test service'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({required this.service});

  final GoService service;

  bool get _isRunning => service.state.toLowerCase() == 'running';

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<MainBloc>();
    final theme = Theme.of(context);

    return ListTile(
      leading: CircleAvatar(child: Icon(_isRunning ? Icons.play_arrow : Icons.stop)),
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
        ],
      ),
      isThreeLine: service.localUrl.trim().isNotEmpty,
      trailing: Wrap(
        spacing: 8,
        children: [
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
        ],
      ),
    );
  }
}
