part of '../template_gallery_screen.dart';

bool _isVerifiedTemplate(_TemplateCardModel template) {
  return template.name == 'navidrome' ||
      template.name == 'jellyfin' ||
      template.name == 'sovereignd-test';
}

Set<String> _defaultVerifiedTemplateKeys() {
  return TemplateGalleryScreen.templates
      .where(_isVerifiedTemplate)
      .map(_templateKey)
      .toSet();
}

String _templateKey(_TemplateCardModel template) => template.image.trim().toLowerCase();

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
  List<String> targets;
  switch (templateName) {
    case 'navidrome':
      targets = ['/data', '/music'];
      break;
    case 'uptime-kuma':
      targets = ['/app/data'];
      break;
    case 'vaultwarden':
      targets = ['/data'];
      break;
    case 'grafana':
      targets = ['/var/lib/grafana'];
      break;
    case 'nextcloud':
      targets = ['/var/www/html'];
      break;
    case 'jellyfin':
      targets = ['/config', '/cache', '/media'];
      break;
    case 'gitea':
      targets = ['/data'];
      break;
    default:
      targets = ['/data'];
      break;
  }

  if (!targets.contains('/misc')) {
    targets.add('/misc');
  }

  return targets;
}

List<GoServiceDefinitionMount> _defaultMountsForTemplate(
  String templateName,
  String serviceName, {
  String? rootOverride,
}) {
  final root = rootOverride ?? _defaultMountRootForName(serviceName);
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

String? _dataRootFromDefinition(GoServiceDefinition definition) {
  final managedBindMounts = definition.mounts
      .where((mount) => mount.managed && mount.type.trim().toLowerCase() == 'bind')
      .toList();
  if (managedBindMounts.isEmpty) return null;

  final firstSource = managedBindMounts.first.source.trim();
  if (firstSource.isEmpty) return null;
  return Directory(firstSource).parent.path;
}

String _folderName(String path) {
  final normalized = path.replaceAll('/', '\\');
  final segments = normalized.split('\\').where((segment) => segment.trim().isNotEmpty).toList();
  return segments.isEmpty ? path : segments.last;
}

String _templateNameFromImage(String image) {
  var base = image.trim();
  if (base.isEmpty) return 'custom-image';

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
  return base.isEmpty ? 'custom-image' : base;
}

String _titleFromImage(String image) {
  final base = _templateNameFromImage(image);
  final words = base.split('-').where((part) => part.isNotEmpty);
  final title = words
      .map((word) => word.isEmpty ? word : '${word[0].toUpperCase()}${word.substring(1)}')
      .join(' ');
  return title.isEmpty ? 'Custom Image' : title;
}
