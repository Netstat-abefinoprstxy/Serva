part of '../homescreen.dart';

extension _CreateServiceSheetStateLogic on _CreateServiceSheetState {
  String _suggestNameFromImage(String image) {
    var base = image.trim();
    if (base.isEmpty) return 'service';

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

  Future<void> _openDockerHubSearch() async {
    final uri = Uri.parse('https://hub.docker.com/search');
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open Docker Hub')),
      );
    }
  }

  Future<void> _pasteImageOrCommand() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text ?? '';

    final image = _extractImageFromPaste(text);
    if (image == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Clipboard does not look like an image or `docker pull <image>` command.'),
        ),
      );
      return;
    }

    setState(() {
      _imageCtrl.text = image;
      if (_nameCtrl.text.trim().isEmpty) {
        final suggested = _suggestNameFromImage(image);
        _nameCtrl.text = suggested;
        if (_mounts.isEmpty &&
            (_mountSourceCtrl.text.trim().isEmpty || _mountSourceCtrl.text.startsWith(_defaultManagedBasePath))) {
          _mountSourceCtrl.text = '${_defaultMountRootForName(suggested)}\\data';
        }
      }
    });
  }

  void _applyTemplate(int index) {
    final template = _createServiceTemplates[index];
    final suffix = Random().nextInt(9000) + 1000;
    final serviceName = '${template.name}-$suffix';
    _nameCtrl.text = serviceName;
    _imageCtrl.text = template.image;
    _portCtrl.text = template.port.toString();
    _mounts
      ..clear()
      ..addAll(_defaultMountsForTemplate(template.name, serviceName));
    _mountSourceCtrl.clear();
    _mountTargetCtrl.clear();
    _mountReadOnly = false;
    _mountManaged = true;
    _mountType = 'bind';
  }

  String _defaultMountRootForName(String serviceName) {
    final sanitized = serviceName.trim().replaceAll(RegExp(r'[^a-zA-Z0-9_-]+'), '-');
    return '$_defaultManagedBasePath\\$sanitized';
  }

  List<String> _defaultMountTargetsForTemplate(String templateName) {
    switch (templateName) {
      case 'navidrome':
        return const ['/data', '/music', '/misc'];
      case 'uptime-kuma':
        return const ['/app/data', '/misc'];
      case 'vaultwarden':
        return const ['/data', '/misc'];
      case 'grafana':
        return const ['/var/lib/grafana', '/misc'];
      case 'nextcloud':
        return const ['/var/www/html', '/misc'];
      case 'jellyfin':
        return const ['/config', '/cache', '/media', '/misc'];
      case 'gitea':
        return const ['/data', '/misc'];
      default:
        return const ['/data', '/misc'];
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

  void _createService() {
    final valid = _formKey.currentState?.validate() ?? false;
    if (!valid) return;

    final mounts = List<GoServiceDefinitionMount>.from(_mounts);
    final draftSource = _mountSourceCtrl.text.trim();
    final draftTarget = _mountTargetCtrl.text.trim();
    if (draftSource.isNotEmpty && draftTarget.isNotEmpty) {
      mounts.add(
        GoServiceDefinitionMount(
          type: _mountType,
          source: draftSource,
          target: draftTarget,
          readOnly: _mountReadOnly,
          managed: _mountManaged,
        ),
      );
    }

    Navigator.of(context).pop();
    widget.bloc.add(
      MainCreateServiceRequested(
        name: _nameCtrl.text.trim(),
        image: _imageCtrl.text.trim(),
        containerPort: int.parse(_portCtrl.text.trim()),
        mounts: mounts,
      ),
    );
  }

  void _addMount() {
    final source = _mountSourceCtrl.text.trim();
    final target = _mountTargetCtrl.text.trim();
    if (source.isEmpty || target.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Both mount source and target are required.')),
      );
      return;
    }

    setState(() {
      _mounts.add(
        GoServiceDefinitionMount(
          type: _mountType,
          source: source,
          target: target,
          readOnly: _mountReadOnly,
          managed: _mountManaged,
        ),
      );
      _mountSourceCtrl.clear();
      _mountTargetCtrl.clear();
      _mountReadOnly = false;
      _mountManaged = true;
      _mountType = 'bind';
    });
  }

  void _removeMount(int index) {
    setState(() {
      _mounts.removeAt(index);
    });
  }

  void _createTest() {
    Navigator.of(context).pop();
    widget.bloc.add(const MainCreateTestRequested());
  }
}
