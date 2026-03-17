part of '../template_gallery_screen.dart';

extension _TemplateGalleryPersistence on _TemplateGalleryScreenState {
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

      TemplateGalleryScreen.customTemplates.value = images.map(_customTemplateFromImage).toList();
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

void _registerCustomTemplate(String image) {
  final current = List<_TemplateCardModel>.from(TemplateGalleryScreen.customTemplates.value);
  if (current.any((template) => template.image == image)) {
    return;
  }

  current.insert(0, _customTemplateFromImage(image));
  TemplateGalleryScreen.customTemplates.value = current;
  _persistCustomTemplates();
}

Future<File> _customTemplateFile() => _servaLocalMetadataFile('custom_templates.json');

Future<File> _verifiedTemplateFile() => _servaLocalMetadataFile('verified_templates.json');

Future<File> _existingServaLocalMetadataFile(String fileName) async {
  final folder = Directory('${_defaultManagedBasePath()}${Platform.pathSeparator}serva-local');
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
  final folder = Directory('${_defaultManagedBasePath()}${Platform.pathSeparator}serva-local');
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
