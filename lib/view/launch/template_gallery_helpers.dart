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
  return _TemplateCardModel(
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
  );
}

Future<void> _prepareTemplateFiles(
  _TemplateCardModel template,
  _TemplateLaunchConfig launchConfig,
) async {
  switch (template.name) {
    case 'element':
      await _prepareElementConfig(launchConfig.mounts);
      break;
    default:
      break;
  }
}

Future<void> _prepareElementConfig(List<GoServiceDefinitionMount> mounts) async {
  GoServiceDefinitionMount? configMount;
  for (final mount in mounts) {
    if (mount.type.trim().toLowerCase() == 'bind' && mount.target.trim() == '/config') {
      configMount = mount;
      break;
    }
  }
  if (configMount == null) return;

  final configDir = Directory(configMount.source);
  if (!await configDir.exists()) {
    await configDir.create(recursive: true);
  }

  final configFile = File('${configDir.path}${Platform.pathSeparator}config.json');
  if (await configFile.exists()) {
    try {
      final raw = await configFile.readAsString();
      jsonDecode(raw);
      return;
    } catch (_) {
      // Replace only known-bad/invalid generated config.
    }
  }

  final config = {
    'default_server_config': {
      'm.homeserver': {
        'base_url': 'https://matrix-client.matrix.org',
        'server_name': 'matrix.org',
      },
      'm.identity_server': {
        'base_url': 'https://vector.im',
      },
    },
    'disable_custom_urls': false,
    'disable_guests': false,
    'disable_login_language_selector': false,
    'disable_3pid_login': false,
    'brand': 'Element',
    'integrations_ui_url': 'https://scalar.vector.im/',
    'integrations_rest_url': 'https://scalar.vector.im/api',
    'integrations_widgets_urls': [
      'https://scalar.vector.im/_matrix/integrations/v1',
      'https://scalar.vector.im/api',
      'https://scalar-staging.vector.im/_matrix/integrations/v1',
      'https://scalar-staging.vector.im/api',
      'https://scalar-staging.riot.im/scalar/api',
    ],
    'bug_report_endpoint_url': 'https://element.io/bugreports/submit',
    'uisi_autorageshake_app': 'element-auto-uisi',
    'default_country_code': 'US',
    'show_labs_settings': false,
    'features': <String, dynamic>{},
    'default_federate': true,
    'default_theme': 'light',
    'room_directory': {
      'servers': ['matrix.org'],
    },
    'enable_presence_by_hs_url': {
      'https://matrix.org': false,
      'https://matrix-client.matrix.org': false,
    },
    'setting_defaults': {
      'breadcrumbs': true,
      'MessageComposerInput.showStickersButton': false,
      'MessageComposerInput.showPollsButton': false,
    },
    'jitsi': {
      'preferred_domain': 'meet.element.io',
    },
    'jitsi_widget': {
      'skip_built_in_welcome_screen': true,
    },
    'voip': {
      'obey_asserted_identity': false,
    },
    'element_call': {
      'url': 'https://call.element.io',
      'participant_limit': 8,
      'brand': 'Element Call',
      'exclusive': false,
    },
    'logout_redirect_url': null,
    'sso_redirect_options': {
      'immediate': false,
      'on_welcome_page': true,
    },
    'map_style_url': 'https://api.maptiler.com/maps/streets/style.json?key=fU3vlMsMn4Jb6dnEIFsx',
  };

  final encoder = const JsonEncoder.withIndent('    ');
  await configFile.writeAsString('${encoder.convert(config)}\n');
}
