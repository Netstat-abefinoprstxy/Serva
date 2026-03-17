part of '../services_overview_screen.dart';

extension _DataTileOps on _DataTile {
  Future<void> _confirmWipe(BuildContext context, MainBloc bloc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Wipe data contents?'),
        content: Text(entry.isDeployed ? 'This will delete everything inside "${entry.rootPath}" while keeping the folder itself. The connected service may break until it recreates its data.' : 'This will delete everything inside "${entry.rootPath}" while keeping the folder itself.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Wipe data')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final root = Directory(entry.rootPath);
      if (root.existsSync()) {
        _wipeDirectoryContents(root);
      } else {
        root.createSync(recursive: true);
      }
      if (entry.isGlobalRoot) TemplateGalleryScreen.resetLocalTemplateState();
      onChanged();
      final liveServiceId = _liveServiceIdForEntry(bloc);
      if (liveServiceId != null) bloc.add(MainRestartRequested(id: liveServiceId));
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(liveServiceId != null ? 'Wiped data and restarted ${entry.serviceName}.' : 'Wiped data in ${entry.rootPath}.')));
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not wipe data: $error')));
    }
  }

  Future<void> _createMiscSubfolder(BuildContext context, MainBloc bloc, String miscRoot) async {
    final controller = TextEditingController();
    final folderName = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create misc folder'),
        content: TextField(controller: controller, autofocus: true, decoration: const InputDecoration(labelText: 'Folder name', border: OutlineInputBorder())),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(controller.text.trim()), child: const Text('Create')),
        ],
      ),
    );
    controller.dispose();

    if (folderName == null || folderName.isEmpty || !context.mounted) return;
    if (folderName.contains('\\') || folderName.contains('/')) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Folder name cannot contain slashes.')));
      return;
    }

    try {
      Directory('$miscRoot${Platform.pathSeparator}$folderName').createSync(recursive: true);
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Created misc folder $folderName')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not create misc folder: $error')));
    }
  }

  Future<void> _deleteMiscSubfolder(BuildContext context, MainBloc bloc, String miscRoot) async {
    final root = Directory(miscRoot);
    final folders = root.existsSync() ? (root.listSync(followLinks: false).whereType<Directory>().map((directory) => directory.path).toList()..sort()) : <String>[];
    if (folders.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No misc subfolders to delete.')));
      return;
    }

    String? selected = folders.first;
    final choice = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete misc folder'),
        content: StatefulBuilder(
          builder: (context, setDialogState) {
            return DropdownButtonFormField<String>(
              value: selected,
              decoration: const InputDecoration(labelText: 'Folder', border: OutlineInputBorder()),
              items: folders.map((path) => DropdownMenuItem<String>(value: path, child: Text(_folderLeafName(path)))).toList(),
              onChanged: (value) => setDialogState(() => selected = value),
            );
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(selected), child: const Text('Delete')),
        ],
      ),
    );

    if (choice == null || !context.mounted) return;

    try {
      final directory = Directory(choice);
      if (directory.existsSync()) directory.deleteSync(recursive: true);
      if (entry.isGlobalRoot) TemplateGalleryScreen.resetLocalTemplateState();
      onChanged();
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted misc folder ${_folderLeafName(choice)}')));
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete misc folder: $error')));
    }
  }

  Future<void> _confirmDelete(BuildContext context, MainBloc bloc) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete data folder?'),
        content: Text(entry.isDeployed ? 'This will permanently delete "${entry.rootPath}" and all of its contents. The connected service may stop working until a new data folder is attached.' : 'This will permanently delete "${entry.rootPath}" and all of its contents.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Delete folder')),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;

    try {
      final root = Directory(entry.rootPath);
      if (root.existsSync()) root.deleteSync(recursive: true);
      if (entry.isGlobalRoot) TemplateGalleryScreen.resetLocalTemplateState();
      onChanged();
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Deleted data folder ${entry.rootPath}')));
      }
    } catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not delete data folder: $error')));
    }
  }

  String? _liveServiceIdForEntry(MainBloc bloc) {
    final state = bloc.state;
    if (state is! MainLoaded) return null;
    for (final service in state.services) {
      if (service.name == entry.serviceName) return service.id;
    }
    return null;
  }

  void _wipeDirectoryContents(Directory directory) {
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is File || entity is Link) {
        entity.deleteSync();
        continue;
      }
      if (entity is Directory) _wipeDirectoryContents(entity);
    }
  }
}
