import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/bloc/main_bloc.dart';
import 'package:serva/bloc/main_event.dart';
import 'package:serva/bloc/main_state.dart';
import 'package:url_launcher/url_launcher.dart';

part 'launch/template_gallery_support.dart';

class TemplateGalleryScreen extends StatefulWidget {
  const TemplateGalleryScreen({super.key});

  static final ValueNotifier<List<_TemplateCardModel>> customTemplates =
      ValueNotifier<List<_TemplateCardModel>>(<_TemplateCardModel>[]);
  static final ValueNotifier<Set<String>> verifiedTemplateKeys =
      ValueNotifier<Set<String>>(<String>{});

  static void resetLocalTemplateState() {
    customTemplates.value = <_TemplateCardModel>[];
    verifiedTemplateKeys.value = _defaultVerifiedTemplateKeys();
  }

  static const templates = <_TemplateCardModel>[
    _TemplateCardModel(
      label: 'Uptime Kuma',
      subtitle: 'Monitoring',
      description: 'Launch a hosted status page and uptime monitor in one click.',
      name: 'uptime-kuma',
      image: 'louislam/uptime-kuma:latest',
      port: 3001,
      icon: Icons.monitor_heart_outlined,
      accent: Color(0xFF4CC9F0),
    ),
    _TemplateCardModel(
      label: 'Navidrome',
      subtitle: 'Music Server',
      description: 'Spin up a personal streaming library with ready-made data folders.',
      name: 'navidrome',
      image: 'deluan/navidrome:latest',
      port: 4533,
      icon: Icons.library_music_outlined,
      accent: Color(0xFFFFC857),
    ),
    _TemplateCardModel(
      label: 'Vaultwarden',
      subtitle: 'Passwords',
      description: 'Create a lightweight Bitwarden-compatible password server.',
      name: 'vaultwarden',
      image: 'vaultwarden/server:latest',
      port: 80,
      icon: Icons.password_rounded,
      accent: Color(0xFF80ED99),
    ),
    _TemplateCardModel(
      label: 'Jellyfin',
      subtitle: 'Media',
      description: 'Stand up your own media server with persistent config storage.',
      name: 'jellyfin',
      image: 'jellyfin/jellyfin:latest',
      port: 8096,
      icon: Icons.movie_filter_outlined,
      accent: Color(0xFFFF7B72),
    ),
    _TemplateCardModel(
      label: 'Grafana',
      subtitle: 'Dashboards',
      description: 'Create a metrics dashboard stack with a single click.',
      name: 'grafana',
      image: 'grafana/grafana:latest',
      port: 3000,
      icon: Icons.insights_outlined,
      accent: Color(0xFFB388FF),
    ),
    _TemplateCardModel(
      label: 'Gitea',
      subtitle: 'Git Hosting',
      description: 'Deploy a self-hosted Git forge without touching Docker commands.',
      name: 'gitea',
      image: 'gitea/gitea:latest',
      port: 3000,
      icon: Icons.source_outlined,
      accent: Color(0xFF72DDF7),
    ),
    _TemplateCardModel(
      label: 'Nextcloud',
      subtitle: 'Files',
      description: 'Self-host a cloud drive alternative with persistent app storage.',
      name: 'nextcloud',
      image: 'nextcloud:latest',
      port: 80,
      icon: Icons.cloud_outlined,
      accent: Color(0xFF8D99AE),
    ),
    _TemplateCardModel(
      label: 'Immich',
      subtitle: 'Photos',
      description: 'Run a self-hosted photo library with managed app data storage.',
      name: 'immich-server',
      image: 'ghcr.io/immich-app/immich-server:release',
      port: 2283,
      icon: Icons.photo_library_outlined,
      accent: Color(0xFF7BDFF2),
    ),
    _TemplateCardModel(
      label: 'Outline',
      subtitle: 'Docs',
      description: 'Create a collaborative docs workspace similar to Notion.',
      name: 'outline',
      image: 'outlinewiki/outline:latest',
      port: 3000,
      icon: Icons.edit_document,
      accent: Color(0xFFF7A072),
    ),
    _TemplateCardModel(
      label: 'Umami',
      subtitle: 'Analytics',
      description: 'Lightweight web analytics with a one-click launch flow.',
      name: 'umami',
      image: 'ghcr.io/umami-software/umami:latest',
      port: 3000,
      icon: Icons.query_stats_rounded,
      accent: Color(0xFFB8F2E6),
    ),
    _TemplateCardModel(
      label: 'Whoogle',
      subtitle: 'Search',
      description: 'Private metasearch front end with a simple managed service setup.',
      name: 'whoogle',
      image: 'benbusby/whoogle-search:latest',
      port: 5000,
      icon: Icons.travel_explore_rounded,
      accent: Color(0xFFA0C4FF),
    ),
    _TemplateCardModel(
      label: 'Focalboard',
      subtitle: 'Projects',
      description: 'Kanban-style project management in a self-hosted service.',
      name: 'focalboard',
      image: 'mattermost/focalboard:latest',
      port: 8000,
      icon: Icons.view_kanban_outlined,
      accent: Color(0xFFFFC6FF),
    ),
    _TemplateCardModel(
      label: 'Mattermost',
      subtitle: 'Chat',
      description: 'Team chat and collaboration with persistent local storage.',
      name: 'mattermost',
      image: 'mattermost/mattermost-team-edition:latest',
      port: 8065,
      icon: Icons.forum_outlined,
      accent: Color(0xFF9BF6FF),
    ),
    _TemplateCardModel(
      label: 'NocoDB',
      subtitle: 'Database UI',
      description: 'Airtable-style interface for your data with a one-click setup.',
      name: 'nocodb',
      image: 'nocodb/nocodb:latest',
      port: 8080,
      icon: Icons.table_chart_outlined,
      accent: Color(0xFFFFD166),
    ),
    _TemplateCardModel(
      label: 'Adminer',
      subtitle: 'DB Viewer',
      description: 'Quick database inspection and management from a tiny container.',
      name: 'adminer',
      image: 'adminer:latest',
      port: 8080,
      icon: Icons.storage_outlined,
      accent: Color(0xFFBDE0FE),
    ),
    _TemplateCardModel(
      label: 'Test (nginx)',
      subtitle: 'Quick Check',
      description: 'Fastest way to confirm Docker, networking, and Serva are all working.',
      name: 'sovereignd-test',
      image: 'nginx:alpine',
      port: 80,
      icon: Icons.science_outlined,
      accent: Color(0xFF06D6A0),
    ),
  ];

  @override
  State<TemplateGalleryScreen> createState() => _TemplateGalleryScreenState();
}

class _TemplateGalleryScreenState extends State<TemplateGalleryScreen> {
  @override
  void initState() {
    super.initState();
    _loadPersistedVerifiedTemplates();
    _loadPersistedCustomTemplates();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;
    final mutedText = textColor.withValues(alpha: 0.74);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            theme.colorScheme.surface,
            Color.alphaBlend(
              theme.colorScheme.primary.withValues(alpha: 0.08),
              theme.colorScheme.surfaceContainerLowest,
            ),
          ],
        ),
      ),
      child: ListView(
        padding: const EdgeInsets.all(10),
        children: [
          Text(
            'One-Click Launch',
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Choose a service tile and Serva will create it with a ready-made image, port, and persistent data layout.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: mutedText,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => _openInfiniteTemplates(context),
                icon: const Icon(Icons.travel_explore_rounded, size: 18),
                label: const Text('Browse Online'),
              ),
              FilledButton.tonalIcon(
                onPressed: () => _pasteImageOrCommand(context),
                icon: const Icon(Icons.content_paste_rounded, size: 18),
                label: const Text('Paste Image'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: theme.colorScheme.outlineVariant),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(Icons.auto_awesome, size: 18, color: theme.colorScheme.onPrimaryContainer),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Single click creates a full service definition, including managed bind mounts under Documents\\Serva.',
                    style: TextStyle(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),
          ValueListenableBuilder<Set<String>>(
            valueListenable: TemplateGalleryScreen.verifiedTemplateKeys,
            builder: (context, verifiedKeys, _) {
              final builtInExperimental = TemplateGalleryScreen.templates
                  .where((template) => !verifiedKeys.contains(_templateKey(template)))
                  .toList();

              return ValueListenableBuilder<List<_TemplateCardModel>>(
                valueListenable: TemplateGalleryScreen.customTemplates,
                builder: (context, customTemplatesValue, _) {
                  final verifiedBuiltIns = TemplateGalleryScreen.templates
                      .where((template) => verifiedKeys.contains(_templateKey(template)))
                      .toList();
                  final verifiedCustom = customTemplatesValue
                      .where((template) => verifiedKeys.contains(_templateKey(template)))
                      .toList();
                  final experimentalCustom = customTemplatesValue
                      .where((template) => !verifiedKeys.contains(_templateKey(template)))
                      .toList();

                  final allExperimental = [
                    ...experimentalCustom,
                    ...builtInExperimental,
                  ];

                  final allVerified = [
                    ...verifiedBuiltIns,
                    ...verifiedCustom,
                  ];

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TemplateSection(
                        title: 'Verified',
                        subtitle: 'Templates we have personally smoke-tested.',
                        templates: allVerified,
                      ),
                      const SizedBox(height: 10),
                      _TemplateSection(
                        title: 'Experimental',
                        subtitle: 'Everything else, including pasted images and unverified presets.',
                        templates: allExperimental,
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _loadPersistedCustomTemplates() async {
    try {
      final file = await _existingServaLocalMetadataFile('custom_templates.json');
      if (!await file.exists()) return;

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return;

      final decoded = jsonDecode(raw);
      if (decoded is! List) return;

      final images = decoded
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet()
          .toList();

      TemplateGalleryScreen.customTemplates.value =
          images.map(_customTemplateFromImage).toList();
    } catch (_) {
      // Keep launch page usable even if local template storage fails.
    }
  }

  Future<void> _loadPersistedVerifiedTemplates() async {
    try {
      final file = await _existingServaLocalMetadataFile('verified_templates.json');
      if (!await file.exists()) {
        TemplateGalleryScreen.verifiedTemplateKeys.value = _defaultVerifiedTemplateKeys();
        return;
      }

      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        TemplateGalleryScreen.verifiedTemplateKeys.value = _defaultVerifiedTemplateKeys();
        return;
      }

      final decoded = jsonDecode(raw);
      if (decoded is! List) {
        TemplateGalleryScreen.verifiedTemplateKeys.value = _defaultVerifiedTemplateKeys();
        return;
      }

      TemplateGalleryScreen.verifiedTemplateKeys.value = decoded
          .whereType<String>()
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toSet();
    } catch (_) {
      TemplateGalleryScreen.verifiedTemplateKeys.value = _defaultVerifiedTemplateKeys();
    }
  }
}

class _TemplateSection extends StatelessWidget {
  const _TemplateSection({
    required this.title,
    required this.subtitle,
    required this.templates,
  });

  final String title;
  final String subtitle;
  final List<_TemplateCardModel> templates;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 2),
        Text(
          subtitle,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 8),
        LayoutBuilder(
          builder: (context, constraints) {
            final width = constraints.maxWidth;
            final crossAxisCount = width >= 1600
                ? 7
                : width >= 1350
                ? 6
                : width >= 1150
                ? 5
                : width >= 900
                ? 4
                : width >= 700
                ? 3
                : width >= 520
                ? 2
                : 1;

            return GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
                childAspectRatio: crossAxisCount == 1 ? 2.4 : crossAxisCount >= 5 ? 1.08 : 1.14,
              ),
              itemCount: templates.length,
              itemBuilder: (context, index) => _TemplateTile(template: templates[index]),
            );
          },
        ),
      ],
    );
  }
}

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template});

  final _TemplateCardModel template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseSurface = theme.colorScheme.surfaceContainerHigh;
    final titleColor = theme.colorScheme.onSurface;
    final bodyColor = titleColor.withValues(alpha: 0.74);
    final isVerified =
        TemplateGalleryScreen.verifiedTemplateKeys.value.contains(_templateKey(template));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _createFromTemplate(context, template),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(template.accent.withValues(alpha: 0.08), baseSurface),
                Color.alphaBlend(template.accent.withValues(alpha: 0.18), theme.colorScheme.surfaceContainer),
              ],
            ),
            border: Border.all(color: template.accent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: template.accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(template.icon, size: 18, color: template.accent),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: isVerified ? 'Move to Experimental' : 'Move to Verified',
                          onPressed: () => _toggleVerified(template),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          icon: Icon(
                            isVerified ? Icons.verified_rounded : Icons.science_outlined,
                            size: 18,
                            color: isVerified ? const Color(0xFF80ED99) : titleColor.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: template.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            template.subtitle.toUpperCase(),
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  template.label,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  template.description,
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MetaPill(label: 'Port ${template.port}'),
                    const _MetaPill(label: 'Persistent'),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      template.subtitle,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: template.accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createFromTemplate(BuildContext context, _TemplateCardModel template) async {
    final bloc = context.read<MainBloc>();
    final launchConfig = await _showTemplateLaunchFlow(context, template);
    if (launchConfig == null || !context.mounted) return;

    bloc.add(
      MainCreateServiceRequested(
        name: launchConfig.serviceName,
        image: template.image,
        containerPort: template.port,
        mounts: launchConfig.mounts,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Creating ${launchConfig.serviceName}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleVerified(_TemplateCardModel template) {
    final current = Set<String>.from(TemplateGalleryScreen.verifiedTemplateKeys.value);
    final key = _templateKey(template);
    if (current.contains(key)) {
      current.remove(key);
    } else {
      current.add(key);
    }
    TemplateGalleryScreen.verifiedTemplateKeys.value = current;
    _persistVerifiedTemplates();
  }
}


Future<_TemplateLaunchConfig?> _showTemplateLaunchFlow(
  BuildContext context,
  _TemplateCardModel template,
) async {
  final existingDataOptions = _existingDataOptions(context);
  final nameController = TextEditingController(text: _generatedServiceName(template.name));
  String? selectedRoot;

  final result = await showModalBottomSheet<_TemplateLaunchConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: template.accent.withValues(alpha: 0.14),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(template.icon, color: template.accent, size: 18),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Launch ${template.label}',
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Set a name and optionally reuse an existing Serva data folder.',
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Instance name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: selectedRoot,
                    decoration: const InputDecoration(
                      labelText: 'Data folder',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Create new managed data folder'),
                      ),
                      ...existingDataOptions.map(
                        (option) => DropdownMenuItem<String?>(
                          value: option.rootPath,
                          child: Text(option.label, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        selectedRoot = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedRoot == null
                        ? 'Serva will create a new managed folder under Documents\\Serva.'
                        : 'Serva will bind this template to the existing folder structure.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          final serviceName = nameController.text.trim();
                          if (serviceName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter an instance name.')),
                            );
                            return;
                          }

                          Navigator.of(context).pop(
                            _TemplateLaunchConfig(
                              serviceName: serviceName,
                              mounts: _defaultMountsForTemplate(
                                template.name,
                                serviceName,
                                rootOverride: selectedRoot,
                              ),
                            ),
                          );
                        },
                        child: const Text('Launch'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  nameController.dispose();
  return result;
}

Future<void> _openInfiniteTemplates(BuildContext context) async {
  final uri = Uri.parse('https://hub.docker.com/search');
  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Could not open Docker Hub')),
    );
  }
}

Future<void> _pasteImageOrCommand(BuildContext context) async {
  final bloc = context.read<MainBloc>();
  final data = await Clipboard.getData(Clipboard.kTextPlain);
  final text = data?.text ?? '';
  final image = _extractImageFromPaste(text);

  if (image == null) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Clipboard does not look like an image or docker pull command.'),
      ),
    );
    return;
  }

  final launchConfig = await _showCustomImageLaunchFlow(
    context,
    image: image,
    suggestedName: _suggestNameFromImage(image),
  );
  if (launchConfig == null || !context.mounted) return;

  _registerCustomTemplate(image);

  bloc.add(
    MainCreateServiceRequested(
      name: launchConfig.serviceName,
      image: image,
      containerPort: 80,
      mounts: launchConfig.mounts,
    ),
  );

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Creating ${launchConfig.serviceName} from clipboard image...'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

void _registerCustomTemplate(String image) {
  final current = List<_TemplateCardModel>.from(TemplateGalleryScreen.customTemplates.value);
  if (current.any((template) => template.image == image)) {
    return;
  }

  current.insert(0, _customTemplateFromImage(image));

  TemplateGalleryScreen.customTemplates.value = current;
  _persistCustomTemplates();
}

Future<_TemplateLaunchConfig?> _showCustomImageLaunchFlow(
  BuildContext context, {
  required String image,
  required String suggestedName,
}) async {
  final existingDataOptions = _existingDataOptions(context);
  final nameController = TextEditingController(text: suggestedName);
  String? selectedRoot;

  final result = await showModalBottomSheet<_TemplateLaunchConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Launch pasted image',
                    style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    image,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Instance name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: selectedRoot,
                    decoration: const InputDecoration(
                      labelText: 'Data folder',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Create new managed data folder'),
                      ),
                      ...existingDataOptions.map(
                        (option) => DropdownMenuItem<String?>(
                          value: option.rootPath,
                          child: Text(option.label, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        selectedRoot = value;
                      });
                    },
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          final serviceName = nameController.text.trim();
                          if (serviceName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter an instance name.')),
                            );
                            return;
                          }

                          Navigator.of(context).pop(
                            _TemplateLaunchConfig(
                              serviceName: serviceName,
                              mounts: _defaultMountsForTemplate(
                                'custom',
                                serviceName,
                                rootOverride: selectedRoot,
                              ),
                            ),
                          );
                        },
                        child: const Text('Launch'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  nameController.dispose();
  return result;
}

List<_ExistingDataOption> _existingDataOptions(BuildContext context) {
  final options = <_ExistingDataOption>[];
  final state = context.read<MainBloc>().state;
  final labelByRoot = <String, String>{};

  if (state is MainLoaded) {
    for (final definition in state.definitions) {
      final root = _dataRootFromDefinition(definition);
      if (root == null || root.trim().isEmpty) continue;
      labelByRoot[root] = '${definition.name} (${_folderName(root)})';
    }
  }

  final baseDir = Directory(_defaultManagedBasePath());
  if (baseDir.existsSync()) {
    for (final entity in baseDir.listSync(followLinks: false).whereType<Directory>()) {
      final root = entity.path;
      options.add(
        _ExistingDataOption(
          rootPath: root,
          label: labelByRoot[root] ?? _folderName(root),
        ),
      );
    }
  }

  options.sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
  return options;
}

String? _extractImageFromPaste(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final pull = RegExp(r'\bdocker(?:\s+model)?\s+pull\s+([^\s]+)', caseSensitive: false);
  final match = pull.firstMatch(text);
  if (match != null) {
    return match.group(1)?.trim();
  }

  if (!text.contains(' ') && (text.contains('/') || text.contains(':'))) {
    return text;
  }

  return null;
}

String _suggestNameFromImage(String image) {
  var base = image.trim();
  if (base.isEmpty) return 'service-${Random().nextInt(9000) + 1000}';

  base = base.replaceAll(RegExp(r'^docker\s+pull\s+', caseSensitive: false), '').trim();

  if ((base.startsWith('"') && base.endsWith('"')) || (base.startsWith("'") && base.endsWith("'"))) {
    base = base.substring(1, base.length - 1);
  }

  final slash = base.lastIndexOf('/');
  if (slash >= 0 && slash < base.length - 1) {
    base = base.substring(slash + 1);
  }

  final colon = base.indexOf(':');
  if (colon > 0) base = base.substring(0, colon);
  final at = base.indexOf('@');
  if (at > 0) base = base.substring(0, at);

  base = base.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-');
  base = base.replaceAll(RegExp(r'^-+|-+$'), '');
  if (base.isEmpty) base = 'service';

  final suffix = Random().nextInt(9000) + 1000;
  return '$base-$suffix';
}

_TemplateCardModel _customTemplateFromImage(String image) {
  return _TemplateCardModel(
    label: _titleFromImage(image),
    subtitle: 'Pasted Image',
    description: image,
    name: _templateNameFromImage(image),
    image: image,
    port: 80,
    icon: Icons.auto_awesome_motion_rounded,
    accent: const Color(0xFFA0C4FF),
  );
}

Future<File> _customTemplateFile() => _servaLocalMetadataFile('custom_templates.json');

Future<File> _verifiedTemplateFile() => _servaLocalMetadataFile('verified_templates.json');

Future<File> _existingServaLocalMetadataFile(String fileName) async {
  final folder = Directory(
    '${_defaultManagedBasePath()}${Platform.pathSeparator}serva-local',
  );
  return File('${folder.path}${Platform.pathSeparator}$fileName');
}

Future<void> _persistCustomTemplates() async {
  try {
    final file = await _customTemplateFile();
    final images = TemplateGalleryScreen.customTemplates.value
        .map((template) => template.image)
        .where((image) => image.trim().isNotEmpty)
        .toList();
    await file.writeAsString(jsonEncode(images));
  } catch (_) {
    // Non-fatal: launch screen still works even if template persistence fails.
  }
}

Future<void> _persistVerifiedTemplates() async {
  try {
    final file = await _verifiedTemplateFile();
    final keys = TemplateGalleryScreen.verifiedTemplateKeys.value.toList()..sort();
    await file.writeAsString(jsonEncode(keys));
  } catch (_) {
    // Non-fatal: launch screen still works even if verified persistence fails.
  }
}

Future<File> _servaLocalMetadataFile(String fileName) async {
  final folder = Directory(
    '${_defaultManagedBasePath()}${Platform.pathSeparator}serva-local',
  );
  if (!await folder.exists()) {
    await folder.create(recursive: true);
  }

  final target = File('${folder.path}${Platform.pathSeparator}$fileName');
  if (!await target.exists()) {
    final legacy = await _legacyMetadataFile(fileName);
    if (await legacy.exists()) {
      try {
        await legacy.copy(target.path);
      } catch (_) {
        // If migration fails, we'll just start fresh in the new location.
      }
    }
  }

  return target;
}

Future<File> _legacyMetadataFile(String fileName) async {
  final directory = await getApplicationSupportDirectory();
  final folder = Directory('${directory.path}${Platform.pathSeparator}serva');
  return File('${folder.path}${Platform.pathSeparator}$fileName');
}
