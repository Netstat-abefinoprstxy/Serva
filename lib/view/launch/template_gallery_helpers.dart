part of '../template_gallery_screen.dart';

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
  final template = _TemplateCardModel(
    label: _titleFromImage(image),
    subtitle: 'Pasted Image',
    description: image,
    comparableTo: const [],
    name: _templateNameFromImage(image),
    image: image,
    port: 80,
    icon: Icons.auto_awesome_motion_rounded,
    accent: const Color(0xFFA0C4FF),
    seedFiles: const [],
    mountTargets: const ['/data', '/misc'],
  );
  return _normalizeTemplateDefaults(template);
}

_TemplateCardModel _customTemplateFromStorageMap(Map<String, dynamic> json) {
  final image = (json['image'] as String? ?? '').trim();
  final label = (json['label'] as String? ?? '').trim();
  final name = (json['name'] as String? ?? '').trim();
  final subtitle = (json['subtitle'] as String? ?? '').trim();
  final description = (json['description'] as String? ?? '').trim();
  final comparableTo = (json['comparableTo'] as List?)?.cast<String>() ?? const <String>[];
  final env = (json['env'] as List?)?.cast<String>() ?? const <String>[];
  final mountTargets = (json['mountTargets'] as List?)?.cast<String>() ?? const <String>[];
  final seedFiles = ((json['seedFiles'] as List?) ?? const [])
      .whereType<Map>()
      .map(
        (entry) => _TemplateSeedFile(
          relativePath: (entry['relativePath'] as String? ?? '').trim(),
          description: (entry['description'] as String? ?? '').trim(),
          contents: entry['contents'] as String? ?? '',
          overwriteIfInvalidJson: entry['overwriteIfInvalidJson'] as bool? ?? false,
        ),
      )
      .where((entry) => entry.relativePath.isNotEmpty)
      .toList();
  final portValue = json['port'];
  final port = portValue is num ? portValue.toInt() : int.tryParse('$portValue') ?? 80;

  final template = _TemplateCardModel(
    label: label.isEmpty ? _titleFromImage(image) : label,
    subtitle: subtitle.isEmpty ? 'Custom Template' : subtitle,
    description: description.isEmpty ? image : description,
    comparableTo: comparableTo.where((value) => value.trim().isNotEmpty).toList(),
    name: name.isEmpty ? _templateNameFromImage(image) : name,
    image: image,
    port: port <= 0 ? 80 : port,
    icon: Icons.auto_awesome_motion_rounded,
    accent: const Color(0xFFA0C4FF),
    env: env.where((value) => value.trim().isNotEmpty).toList(),
    seedFiles: seedFiles,
    mountTargets: mountTargets.isEmpty ? const ['/data', '/misc'] : mountTargets,
  );
  return _normalizeTemplateDefaults(template);
}

Map<String, dynamic> _customTemplateToStorageMap(_TemplateCardModel template) {
  template = _normalizeTemplateDefaults(template);
  return {
    'label': template.label,
    'subtitle': template.subtitle,
    'description': template.description,
    'comparableTo': template.comparableTo,
    'name': template.name,
    'image': template.image,
    'port': template.port,
    'env': template.env,
    'mountTargets': _mountTargetsForTemplateCard(template),
    'seedFiles': template.seedFiles
        .map(
          (file) => {
            'relativePath': file.relativePath,
            'description': file.description,
            'contents': file.contents,
            'overwriteIfInvalidJson': file.overwriteIfInvalidJson,
          },
        )
        .toList(),
  };
}

_TemplateCardModel _normalizeTemplateDefaults(_TemplateCardModel template) {
  if (_templateKey(template) != 'tailscale/tailscale:stable') {
    return template;
  }

  final env = List<String>.from(template.env);
  void upsertEnv(String key, String value) {
    env.removeWhere((entry) => entry.startsWith('$key='));
    env.add('$key=$value');
  }

  upsertEnv('TS_STATE_DIR', '/var/lib/tailscale');
  upsertEnv('TS_USERSPACE', 'true');
  upsertEnv(
    'TS_EXTRA_ARGS',
    '--advertise-routes=$_allPrivateSubnetRoutes --advertise-exit-node',
  );

  final mountTargets = _mountTargetsForTemplateCard(template);
  if (!mountTargets.contains('/var/lib/tailscale')) {
    mountTargets.add('/var/lib/tailscale');
  }
  if (!mountTargets.contains('/misc')) {
    mountTargets.add('/misc');
  }

  return _TemplateCardModel(
    label: template.label,
    subtitle: template.subtitle,
    description: template.description,
    comparableTo: template.comparableTo,
    name: template.name,
    image: template.image,
    port: template.port,
    icon: template.icon,
    accent: template.accent,
    env: env,
    seedFiles: template.seedFiles,
    mountTargets: mountTargets,
  );
}

List<_TemplateCardModel> _mergeTemplateLists(
  List<_TemplateCardModel> builtIns,
  List<_TemplateCardModel> customTemplates,
) {
  final byKey = <String, _TemplateCardModel>{};
  for (final template in builtIns) {
    byKey[_templateKey(template)] = template;
  }
  for (final template in customTemplates) {
    byKey[_templateKey(template)] = template;
  }
  return byKey.values.toList()
    ..sort((a, b) => a.label.toLowerCase().compareTo(b.label.toLowerCase()));
}

Future<void> _prepareTemplateFiles(
  _TemplateCardModel template,
  _TemplateLaunchConfig launchConfig,
) async {
  if (template.seedFiles.isEmpty) return;

  final root = _serviceRootFromMounts(launchConfig.mounts);
  if (root == null) return;

  final rootDir = Directory(root);
  if (!await rootDir.exists()) {
    await rootDir.create(recursive: true);
  }

  for (final seedFile in template.seedFiles) {
    final relativePath = seedFile.relativePath.trim().replaceAll('/', Platform.pathSeparator);
    if (relativePath.isEmpty) continue;

    final file = File('${rootDir.path}${Platform.pathSeparator}$relativePath');
    final parent = file.parent;
    if (!await parent.exists()) {
      await parent.create(recursive: true);
    }

    if (await file.exists()) {
      if (!seedFile.overwriteIfInvalidJson) {
        continue;
      }

      try {
        final raw = await file.readAsString();
        jsonDecode(raw);
        continue;
      } catch (_) {
        // Replace invalid JSON files when explicitly allowed.
      }
    }

    await file.writeAsString(seedFile.contents);
  }
}

String? _serviceRootFromMounts(List<GoServiceDefinitionMount> mounts) {
  for (final mount in mounts) {
    if (mount.type.trim().toLowerCase() != 'bind') continue;
    final source = mount.source.trim();
    if (source.isEmpty) continue;
    return Directory(source).parent.path;
  }
  return null;
}
