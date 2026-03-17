part of '../services_overview_screen.dart';

extension _ServicesOverviewStorage on _ServicesOverviewScreenState {
  List<String> _discoverServaDataRoots() {
    final base = Directory(_servaManagedBasePath());
    if (!base.existsSync()) return const [];

    try {
      return base
          .listSync(followLinks: false)
          .whereType<Directory>()
          .where((directory) => _folderLeafName(directory.path).toLowerCase() != 'serva-local')
          .map((directory) => directory.path)
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<Map<String, double>> _loadFolderSizes(List<String> roots) async {
    if (roots.isEmpty) return const {};

    final command = StringBuffer()..writeln("\$folders = [ordered]@{}");
    for (final root in roots) {
      command
        ..writeln("\$folderPath = '${_psEscape(root)}'")
        ..writeln("if (Test-Path -LiteralPath \$folderPath) {")
        ..writeln("  \$sum = (Get-ChildItem -LiteralPath \$folderPath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum")
        ..writeln("  \$folders['${_psEscape(root)}'] = if (\$null -eq \$sum) { 0 } else { [double]\$sum }")
        ..writeln("} else {")
        ..writeln("  \$folders['${_psEscape(root)}'] = 0")
        ..writeln("}");
    }
    command.writeln("\$folders | ConvertTo-Json -Compress");

    try {
      final result = await Process.run('powershell', ['-NoProfile', '-Command', command.toString()]);
      if (result.exitCode != 0) return const {};
      final raw = result.stdout.toString().trim();
      if (raw.isEmpty) return const {};
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      final values = <String, double>{};
      for (final entry in json.entries) {
        values[entry.key.toString()] = _asDouble(entry.value);
      }
      return values;
    } catch (_) {
      return const {};
    }
  }

  Map<String, List<String>> _loadMiscSubfolders(List<_DataEntry> dataEntries) {
    final result = <String, List<String>>{};

    for (final entry in dataEntries) {
      GoServiceDefinitionMount? miscMount;
      for (final mount in entry.mounts) {
        if (mount.target.trim() == '/misc') {
          miscMount = mount;
          break;
        }
      }
      if (miscMount == null) {
        result[entry.rootPath] = const [];
        continue;
      }

      final miscRoot = Directory(miscMount.source);
      if (!miscRoot.existsSync()) {
        result[entry.rootPath] = const [];
        continue;
      }

      try {
        final folders = miscRoot
            .listSync(followLinks: false)
            .whereType<Directory>()
            .map((directory) => '/misc/${_folderLeafName(directory.path)}')
            .toList()
          ..sort();
        result[entry.rootPath] = folders;
      } catch (_) {
        result[entry.rootPath] = const [];
      }
    }

    return result;
  }

  Future<Map<String, double>> _loadServaStorageMetrics(List<GoServiceDefinition> definitions) async {
    final serviceRoots = <String, String>{};

    for (final definition in definitions) {
      final root = _serviceMountRootFromDefinition(definition);
      if (root != null && root.startsWith(_servaManagedBasePath())) {
        serviceRoots[definition.name] = root;
      }
    }

    final command = StringBuffer()..writeln("\$services = [ordered]@{}");
    serviceRoots.forEach((name, path) {
      command
        ..writeln("\$servicePath = '${_psEscape(path)}'")
        ..writeln("if (Test-Path -LiteralPath \$servicePath) {")
        ..writeln("  \$sum = (Get-ChildItem -LiteralPath \$servicePath -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum")
        ..writeln("  \$services['${_psEscape(name)}'] = if (\$null -eq \$sum) { 0 } else { [double]\$sum }")
        ..writeln("} else {")
        ..writeln("  \$services['${_psEscape(name)}'] = 0")
        ..writeln("}");
    });
    command.writeln("\$services | ConvertTo-Json -Compress");

    try {
      final result = await Process.run('powershell', ['-NoProfile', '-Command', command.toString()]);
      if (result.exitCode != 0) return const {};
      final raw = result.stdout.toString().trim();
      if (raw.isEmpty) return const {};
      final json = jsonDecode(raw);
      if (json is! Map) return const {};
      final values = <String, double>{};
      for (final entry in json.entries) {
        values[entry.key.toString()] = _asDouble(entry.value);
      }
      return values;
    } catch (_) {
      return const {};
    }
  }
}
