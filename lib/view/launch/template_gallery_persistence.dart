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

      final templates = <_TemplateCardModel>[];
      for (final entry in decoded) {
        if (entry is String) {
          final image = entry.trim();
          if (image.isNotEmpty) {
            templates.add(_customTemplateFromImage(image));
          }
        } else if (entry is Map) {
          final mapped = entry.cast<String, dynamic>();
          final image = (mapped['image'] as String? ?? '').trim();
          if (image.isNotEmpty) {
            templates.add(_customTemplateFromStorageMap(mapped));
          }
        }
      }

      final byKey = <String, _TemplateCardModel>{};
      for (final template in templates) {
        byKey[_templateKey(template)] = template;
      }
      TemplateGalleryScreen.customTemplates.value = byKey.values.toList();
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

void _registerCustomTemplate(_TemplateCardModel template) {
  template = _normalizeTemplateDefaults(template);
  final current = List<_TemplateCardModel>.from(TemplateGalleryScreen.customTemplates.value);
  final key = _templateKey(template);
  final existingIndex = current.indexWhere((entry) => _templateKey(entry) == key);
  if (existingIndex >= 0) {
    current[existingIndex] = template;
  } else {
    current.insert(0, template);
  }

  TemplateGalleryScreen.customTemplates.value = current;
  _persistCustomTemplates();
}

void _removeCustomTemplate(_TemplateCardModel template) {
  final current = List<_TemplateCardModel>.from(TemplateGalleryScreen.customTemplates.value);
  current.removeWhere((entry) => _templateKey(entry) == _templateKey(template));
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
    final templates = TemplateGalleryScreen.customTemplates.value
        .where((template) => template.image.trim().isNotEmpty)
        .map(_customTemplateToStorageMap)
        .toList();
    await file.writeAsString(jsonEncode(templates));
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
