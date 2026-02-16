import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sovereign/api/go_models.dart';
import 'dart:math';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

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
            return _LoadedView(state: state, onCreateService: () => _showCreateServiceSheet(context));
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

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateServiceSheet(bloc: bloc),
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
  const _LoadedView({required this.state, required this.onCreateService});

  final MainLoaded state;
  final VoidCallback onCreateService;

  @override
  Widget build(BuildContext context) {
    final services = state.services;

    return Column(
      children: [
        _Header(healthOk: state.healthOk, lastMessage: state.lastMessage),
        const Divider(height: 1),
        Expanded(
          child: services.isEmpty
              ? _EmptyServices(onCreate: onCreateService)
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

class _CreateServiceSheet extends StatefulWidget {
  const _CreateServiceSheet({required this.bloc});

  final MainBloc bloc;

  @override
  State<_CreateServiceSheet> createState() => _CreateServiceSheetState();
}

class _CreateServiceSheetState extends State<_CreateServiceSheet> {
  static const templates = <({String label, String name, String image, int port})>[
    (label: 'Test (nginx)', name: 'sovereignd-test', image: 'nginx:alpine', port: 80),
    (label: 'Vaultwarden', name: 'vaultwarden', image: 'vaultwarden/server:latest', port: 80),
    (label: 'Jellyfin', name: 'jellyfin', image: 'jellyfin/jellyfin:latest', port: 8096),
    (label: 'Navidrome', name: 'navidrome', image: 'deluan/navidrome:latest', port: 4533),
    (label: 'Minecraft', name: 'minecraft', image: 'itzg/minecraft-server:latest', port: 25565),
    (label: 'Uptime Kuma', name: 'uptime-kuma', image: 'louislam/uptime-kuma:latest', port: 3001),
  ];

  final _nameCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '80');
  final _formKey = GlobalKey<FormState>();

  int _selectedTemplate = 0;

  String _suggestNameFromImage(String image) {
    // Take the last path segment, strip tag/digest.
    var base = image.trim();
    if (base.isEmpty) return 'service';

    // Remove any leading command fragments just in case.
    base = base.replaceAll(RegExp(r'^docker\s+pull\s+', caseSensitive: false), '').trim();

    // Trim quotes.
    if ((base.startsWith('"') && base.endsWith('"')) || (base.startsWith("'") && base.endsWith("'"))) {
      base = base.substring(1, base.length - 1);
    }

    // Strip registry path to last segment.
    final slash = base.lastIndexOf('/');
    if (slash >= 0 && slash < base.length - 1) {
      base = base.substring(slash + 1);
    }

    // Strip tag or digest.
    final colon = base.indexOf(':');
    if (colon > 0) base = base.substring(0, colon);
    final at = base.indexOf('@');
    if (at > 0) base = base.substring(0, at);

    // Sanitize.
    base = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
    base = base.replaceAll(RegExp(r'^-+|-+$'), '');
    if (base.isEmpty) base = 'service';

    final suffix = Random().nextInt(9000) + 1000;
    return '$base-$suffix';
  }

  String? _extractImageFromPaste(String input) {
    var s = input.trim();
    if (s.isEmpty) return null;

    // Common copy/paste from docs or Docker Desktop buttons.
    // Support: `docker pull <image>`
    final pull = RegExp(r'\bdocker\s+pull\s+([^\s]+)', caseSensitive: false);
    final pullMatch = pull.firstMatch(s);
    if (pullMatch != null) {
      return pullMatch.group(1)?.trim();
    }

    // If user pastes just an image name, accept it.
    // Basic heuristic: contains a slash or colon tag, and no spaces.
    if (!s.contains(' ') && (s.contains('/') || s.contains(':'))) {
      return s;
    }

    return null;
  }

  Future<void> _openDockerHubSearch() async {
    final uri = Uri.parse('https://hub.docker.com/search');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open Docker Hub')));
    }
  }

  Future<void> _pasteImageOrCommand() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';

    final image = _extractImageFromPaste(text);
    if (image == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Clipboard does not look like an image or `docker pull <image>` command.')),
      );
      return;
    }

    setState(() {
      _imageCtrl.text = image;
      // If the name looks like it came from a template, keep it; otherwise auto-suggest.
      if (_nameCtrl.text.trim().isEmpty) {
        _nameCtrl.text = _suggestNameFromImage(image);
      }
    });
  }

  @override
  void initState() {
    super.initState();
    _applyTemplate(_selectedTemplate);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imageCtrl.dispose();
    _portCtrl.dispose();
    super.dispose();
  }

  void _applyTemplate(int index) {
    final t = templates[index];
    final suffix = Random().nextInt(9000) + 1000;
    _nameCtrl.text = '${t.name}-$suffix';
    _imageCtrl.text = t.image;
    _portCtrl.text = t.port.toString();
  }

  void _createService() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final name = _nameCtrl.text.trim();
    final image = _imageCtrl.text.trim();
    final port = int.parse(_portCtrl.text.trim());

    Navigator.of(context).pop();
    widget.bloc.add(MainCreateServiceRequested(name: name, image: image, containerPort: port));
  }

  void _createTest() {
    Navigator.of(context).pop();
    widget.bloc.add(const MainCreateTestRequested());
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text('Create service', style: Theme.of(context).textTheme.titleLarge)),
              IconButton(
                tooltip: 'Docker Hub',
                onPressed: _openDockerHubSearch,
                icon: const Icon(Icons.travel_explore),
              ),
              IconButton(
                tooltip: 'Paste image/command',
                onPressed: _pasteImageOrCommand,
                icon: const Icon(Icons.content_paste),
              ),
            ],
          ),
          const SizedBox(height: 12),

          Text('Template', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            value: _selectedTemplate,
            items: [
              for (var i = 0; i < templates.length; i++)
                DropdownMenuItem<int>(value: i, child: Text(templates[i].label)),
            ],
            onChanged: (v) {
              if (v == null) return;
              setState(() {
                _selectedTemplate = v;
                _applyTemplate(v);
              });
            },
          ),

          const SizedBox(height: 12),

          Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(labelText: 'Name', hintText: 'e.g. jellyfin-1234'),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Name is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _imageCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Image',
                    hintText: 'e.g. nginx:alpine  (or paste: docker pull mcp/grafana)',
                  ),
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || v.trim().isEmpty) ? 'Image is required' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _portCtrl,
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
                  onPressed: _createTest,
                  icon: const Icon(Icons.science_outlined),
                  label: const Text('Create test'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _createService,
                  icon: const Icon(Icons.add),
                  label: const Text('Create'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
