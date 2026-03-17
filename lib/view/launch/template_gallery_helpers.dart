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
    name: _templateNameFromImage(image),
    image: image,
    port: 80,
    icon: Icons.auto_awesome_motion_rounded,
    accent: const Color(0xFFA0C4FF),
  );
}
