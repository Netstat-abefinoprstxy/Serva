import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sovereign/api/go_models.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';

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
        onPressed: () => _showCreateServiceSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Create service'),
      ),
    );
  }

  void _showCreateServiceSheet(BuildContext context) {
    final bloc = context.read<MainBloc>();

    // Some sensible starter templates. Users can still type anything.
    const templates = <({String label, String name, String image, int port})>[
      (label: 'Test (nginx)', name: 'sovereignd-test', image: 'nginx:alpine', port: 80),
      (label: 'Vaultwarden', name: 'vaultwarden', image: 'vaultwarden/server:latest', port: 80),
      (label: 'Jellyfin', name: 'jellyfin', image: 'jellyfin/jellyfin:latest', port: 8096),
      (label: 'Navidrome', name: 'navidrome', image: 'deluan/navidrome:latest', port: 4533),
      (label: 'Minecraft', name: 'minecraft', image: 'itzg/minecraft-server:latest', port: 25565),
      (label: 'Uptime Kuma', name: 'uptime-kuma', image: 'louislam/uptime-kuma:latest', port: 3001),
    ];

    final nameCtrl = TextEditingController();
    final imageCtrl = TextEditingController();
    final portCtrl = TextEditingController(text: '80');
    final formKey = GlobalKey<FormState>();

    int selectedTemplate = 0;

    void applyTemplate(int index) {
      final t = templates[index];
      // Add a tiny suffix to avoid collisions if the user creates multiple.
      final suffix = Random().nextInt(9000) + 1000;
      nameCtrl.text = '${t.name}-$suffix';
      imageCtrl.text = t.image;
      portCtrl.text = t.port.toString();
    }

    applyTemplate(selectedTemplate);

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (ctx) {
        final bottomPadding = MediaQuery.of(ctx).viewInsets.bottom;

        return StatefulBuilder(
          builder: (ctx, setState) {
            return Padding(
              padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16 + bottomPadding),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Create service', style: Theme.of(ctx).textTheme.titleLarge),
                  const SizedBox(height: 12),

                  // Quick picks
                  Text('Template', style: Theme.of(ctx).textTheme.titleSmall),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    value: selectedTemplate,
                    items: [
                      for (var i = 0; i < templates.length; i++)
                        DropdownMenuItem<int>(value: i, child: Text(templates[i].label)),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      setState(() {
                        selectedTemplate = v;
                        applyTemplate(v);
                      });
                    },
                  ),

                  const SizedBox(height: 12),

                  Form(
                    key: formKey,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextFormField(
                          controller: nameCtrl,
                          decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. jellyfin-1234'),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Name is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: imageCtrl,
                          decoration: const InputDecoration(labelText: 'Image', hintText: 'e.g. nginx:alpine'),
                          textInputAction: TextInputAction.next,
                          validator: (v) {
                            if (v == null || v.trim().isEmpty) return 'Image is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          controller: portCtrl,
                          decoration: const InputDecoration(labelText: 'Container port', hintText: 'e.g. 80'),
                          keyboardType: TextInputType.number,
                          validator: (v) {
                            final raw = v?.trim();
                            if (raw == null || raw.isEmpty) return 'Port is required';
                            final p = int.tryParse(raw);
                            if (p == null || p <= 0 || p > 65535) return 'Port must be 1-65535';
                            return null;
                          },
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 16),

                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            bloc.add(const MainCreateTestRequested());
                          },
                          icon: const Icon(Icons.science_outlined),
                          label: const Text('Create test'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: () {
                            final valid = formKey.currentState?.validate() ?? false;
                            if (!valid) return;

                            final name = nameCtrl.text.trim();
                            final image = imageCtrl.text.trim();
                            final port = int.parse(portCtrl.text.trim());

                            Navigator.of(ctx).pop();
                            bloc.add(MainCreateServiceRequested(name: name, image: image, containerPort: port));
                          },
                          icon: const Icon(Icons.add),
                          label: const Text('Create'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            );
          },
        );
      },
    ).whenComplete(() {
      nameCtrl.dispose();
      imageCtrl.dispose();
      portCtrl.dispose();
    });
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
              ? _EmptyServices(onCreate: () => const HomeScreen()._showCreateServiceSheet(context))
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
            const Text('No services yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600)),
            const SizedBox(height: 8),
            const Text('Create your first service to confirm everything is wired up.', textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: onCreate, icon: const Icon(Icons.add), label: const Text('Create service')),
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

  Future<void> _openUrl(BuildContext context, String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) return;

    Uri? uri;
    try {
      uri = Uri.parse(trimmed);
    } catch (_) {
      uri = null;
    }

    if (uri == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL')));
      return;
    }

    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);

    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
    }
  }

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
              child: InkWell(
                onTap: () => _openUrl(context, service.localUrl),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: Text(
                    service.localUrl,
                    style: theme.textTheme.bodySmall?.copyWith(decoration: TextDecoration.underline),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
            ),
        ],
      ),
      isThreeLine: service.localUrl.trim().isNotEmpty,
      trailing: Wrap(
        spacing: 8,
        children: [
          if (service.localUrl.trim().isNotEmpty)
            IconButton(
              tooltip: 'Open',
              onPressed: () => _openUrl(context, service.localUrl),
              icon: const Icon(Icons.open_in_new),
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
        ],
      ),
    );
  }
}
