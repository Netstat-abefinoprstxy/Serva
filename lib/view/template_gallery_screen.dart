import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/services.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/bloc/main_bloc.dart';
import 'package:serva/bloc/main_event.dart';
import 'package:url_launcher/url_launcher.dart';

class TemplateGalleryScreen extends StatelessWidget {
  const TemplateGalleryScreen({super.key});

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
          const SizedBox(height: 10),
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
                itemBuilder: (context, index) {
                  final template = templates[index];
                  return _TemplateTile(template: template);
                },
              );
            },
          ),
        ],
      ),
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

  void _createFromTemplate(BuildContext context, _TemplateCardModel template) {
    final bloc = context.read<MainBloc>();
    final serviceName = _generatedServiceName(template.name);
    final mounts = _defaultMountsForTemplate(template.name, serviceName);

    bloc.add(
      MainCreateServiceRequested(
        name: serviceName,
        image: template.image,
        containerPort: template.port,
        mounts: mounts,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Creating ${template.label}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TemplateCardModel {
  const _TemplateCardModel({
    required this.label,
    required this.subtitle,
    required this.description,
    required this.name,
    required this.image,
    required this.port,
    required this.icon,
    required this.accent,
  });

  final String label;
  final String subtitle;
  final String description;
  final String name;
  final String image;
  final int port;
  final IconData icon;
  final Color accent;
}

String _generatedServiceName(String baseName) {
  final suffix = Random().nextInt(9000) + 1000;
  return '$baseName-$suffix';
}

String _defaultManagedBasePath() {
  final userProfile = Platform.environment['USERPROFILE'];
  if (userProfile != null && userProfile.trim().isNotEmpty) {
    return '$userProfile\\Documents\\Serva';
  }

  final home = Platform.environment['HOME'];
  if (home != null && home.trim().isNotEmpty) {
    return '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}Serva';
  }

  return 'Documents${Platform.pathSeparator}Serva';
}

String _defaultMountRootForName(String serviceName) {
  final sanitized = serviceName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
  return '${_defaultManagedBasePath()}\\$sanitized';
}

List<String> _defaultMountTargetsForTemplate(String templateName) {
  switch (templateName) {
    case 'navidrome':
      return const ['/data', '/music'];
    case 'uptime-kuma':
      return const ['/app/data'];
    case 'vaultwarden':
      return const ['/data'];
    case 'grafana':
      return const ['/var/lib/grafana'];
    case 'nextcloud':
      return const ['/var/www/html'];
    case 'jellyfin':
      return const ['/config'];
    case 'gitea':
      return const ['/data'];
    default:
      return const ['/data'];
  }
}

List<GoServiceDefinitionMount> _defaultMountsForTemplate(String templateName, String serviceName) {
  final root = _defaultMountRootForName(serviceName);
  return _defaultMountTargetsForTemplate(templateName)
      .map(
        (target) => GoServiceDefinitionMount(
          type: 'bind',
          source: '$root\\${_subfolderNameForTarget(target)}',
          target: target,
          readOnly: false,
          managed: true,
        ),
      )
      .toList();
}

String _subfolderNameForTarget(String target) {
  final segments = target.split('/').where((segment) => segment.trim().isNotEmpty).toList();
  if (segments.isEmpty) {
    return 'data';
  }
  return segments.join('-');
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

  final serviceName = _suggestNameFromImage(image);
  final mounts = _defaultMountsForTemplate('custom', serviceName);

  bloc.add(
    MainCreateServiceRequested(
      name: serviceName,
      image: image,
      containerPort: 80,
      mounts: mounts,
    ),
  );

  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('Creating $serviceName from clipboard image...'),
      behavior: SnackBarBehavior.floating,
    ),
  );
}

String? _extractImageFromPaste(String input) {
  final text = input.trim();
  if (text.isEmpty) return null;

  final pull = RegExp(r'\bdocker\s+pull\s+([^\s]+)', caseSensitive: false);
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
