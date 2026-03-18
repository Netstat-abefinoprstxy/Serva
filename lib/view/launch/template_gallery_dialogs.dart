part of '../template_gallery_screen.dart';

Future<_TemplateLaunchConfig?> _showTemplateLaunchFlow(
  BuildContext context,
  _TemplateCardModel template,
) {
  return _showLaunchFlowSheet(
    context,
    title: 'Launch ${template.label}',
    subtitle: 'Set a name and optionally reuse an existing Serva data folder.',
    initialName: _generatedServiceName(template.name),
    imageLabel: null,
    leadingIcon: Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: template.accent.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(template.icon, color: template.accent, size: 18),
    ),
    mountBuilder: (serviceName, selectedRoot) =>
        _mountsForTargets(_mountTargetsForTemplateCard(template), serviceName, rootOverride: selectedRoot),
    env: template.env,
  );
}

Future<void> _showTemplateDetailsSheet(
  BuildContext context,
  _TemplateCardModel template,
) {
  final mountTargets = _mountTargetsForTemplateCard(template);
  final isCustomTemplate = TemplateGalleryScreen.customTemplates.value
      .any((entry) => _templateKey(entry) == _templateKey(template));

  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      return Padding(
        padding: EdgeInsets.only(
          left: 12,
          right: 12,
          top: 12,
          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
        ),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: theme.colorScheme.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: template.accent.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(template.icon, color: template.accent, size: 20),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          template.label,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          template.subtitle,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _templateDetailRow(context, 'Image', template.image),
              _templateDetailRow(context, 'Port', '${template.port}'),
              _templateDetailRow(
                context,
                'Comparisons',
                template.comparableTo.isEmpty ? 'None' : template.comparableTo.join(', '),
              ),
              const SizedBox(height: 12),
              Text(
                'Mounts',
                style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: mountTargets.map((target) => _MetaPill(label: target)).toList(),
              ),
              if (template.seedFiles.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Custom files',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ...template.seedFiles.map(
                  (file) => _templateDetailRow(
                    context,
                    file.relativePath,
                    file.description,
                  ),
                ),
              ],
              if (template.env.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(
                  'Environment',
                  style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 6),
                ...template.env.map((entry) => _templateDetailRow(context, 'ENV', entry)),
              ],
              const SizedBox(height: 12),
              Text(
                template.description,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.78),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  if (isCustomTemplate)
                    TextButton.icon(
                      onPressed: () async {
                        final confirmed = await showDialog<bool>(
                          context: context,
                          builder: (dialogContext) => AlertDialog(
                            title: const Text('Delete template?'),
                            content: Text(
                              'Remove ${template.label} from Launch? '
                              'If this template overrides a built-in preset, the built-in version will show again.',
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.of(dialogContext).pop(false),
                                child: const Text('Cancel'),
                              ),
                              FilledButton(
                                onPressed: () => Navigator.of(dialogContext).pop(true),
                                child: const Text('Delete'),
                              ),
                            ],
                          ),
                        );
                        if (confirmed != true || !context.mounted) return;
                        _removeCustomTemplate(template);
                        Navigator.of(context).pop();
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Removed ${template.label}.'),
                            behavior: SnackBarBehavior.floating,
                          ),
                        );
                      },
                      icon: const Icon(Icons.delete_outline_rounded),
                      label: const Text('Delete'),
                    ),
                  if (isCustomTemplate) const SizedBox(width: 8),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.of(context).pop();
                      TemplateGalleryScreen.showEditTemplateSheet(context, template);
                    },
                    icon: const Icon(Icons.edit_outlined),
                    label: const Text('Edit'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ],
          ),
        ),
      );
    },
  );
}

Future<_TemplateLaunchConfig?> _showCustomImageLaunchFlow(
  BuildContext context, {
  required String image,
  required String suggestedName,
}) {
  return _showLaunchFlowSheet(
    context,
    title: 'Launch pasted image',
    initialName: suggestedName,
    imageLabel: image,
    mountBuilder: (serviceName, selectedRoot) =>
        _mountsForTargets(const ['/data', '/misc'], serviceName, rootOverride: selectedRoot),
    env: const [],
  );
}

Future<void> _showCreateTemplateSheet(
  BuildContext context, {
  _TemplateCardModel? existingTemplate,
}) async {
  final theme = Theme.of(context);
  final isEditing = existingTemplate != null;
  final imageController = TextEditingController(text: existingTemplate?.image ?? '');
  final labelController = TextEditingController(text: existingTemplate?.label ?? '');
  final baseNameController = TextEditingController(text: existingTemplate?.name ?? '');
  final portController = TextEditingController(text: '${existingTemplate?.port ?? 80}');
  final subtitleController = TextEditingController(text: existingTemplate?.subtitle ?? 'Custom Template');
  final descriptionController = TextEditingController(text: existingTemplate?.description ?? '');
  final comparisonController = TextEditingController();
  final mountController = TextEditingController(text: '/data');
  final envController = TextEditingController();
  final subnetController = TextEditingController();
  final filePathController = TextEditingController();
  final fileDescriptionController = TextEditingController();
  final fileContentsController = TextEditingController();
  final mountTargets = List<String>.from(
    (existingTemplate?.mountTargets.isNotEmpty ?? false)
        ? existingTemplate!.mountTargets.where((target) => _normalizeMountTarget(target) != '/misc')
        : const ['/data'],
  );
  final comparisonTags = List<String>.from(existingTemplate?.comparableTo ?? const []);
  final envEntries = List<String>.from(existingTemplate?.env ?? const []);
  final customFiles = List<_TemplateSeedFile>.from(existingTemplate?.seedFiles ?? const []);
  final initialExtraArgs = _envValue(envEntries, 'TS_EXTRA_ARGS') ?? '';
  final initialRoutes = _extractAdvertisedRoutes(initialExtraArgs);
  var advertiseAllSubnets = _isAllPrivateSubnetSet(initialRoutes);
  subnetController.text = advertiseAllSubnets ? '' : initialRoutes;
  var advertiseExitNode = _containsExitNodeFlag(initialExtraArgs);

  try {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            bool isTailscaleDraft() {
              final image = imageController.text.trim().toLowerCase();
              final baseName = baseNameController.text.trim().toLowerCase();
              return image.contains('tailscale') || baseName == 'tailscale';
            }

            void addMountTarget() {
              final normalized = _normalizeMountTarget(mountController.text);
              if (normalized.isEmpty || normalized == '/misc' || mountTargets.contains(normalized)) return;
              setSheetState(() {
                mountTargets.add(normalized);
                mountTargets.sort();
                mountController.clear();
              });
            }

            void addComparisonTag() {
              final value = comparisonController.text.trim();
              if (value.isEmpty || comparisonTags.contains(value)) return;
              setSheetState(() {
                comparisonTags.add(value);
                comparisonController.clear();
              });
            }

            void syncTailscaleEnv() {
              envEntries.removeWhere((entry) => entry.startsWith('TS_EXTRA_ARGS='));
              final args = <String>[];
              final routes = advertiseAllSubnets
                  ? _allPrivateSubnetRoutes
                  : subnetController.text.trim();
              if (routes.isNotEmpty) {
                args.add('--advertise-routes=$routes');
              }
              if (advertiseExitNode) {
                args.add('--advertise-exit-node');
              }
              envEntries.add('TS_EXTRA_ARGS=${args.join(' ')}');
            }

            void addEnvEntry() {
              final value = envController.text.trim();
              if (value.isEmpty || !value.contains('=') || envEntries.contains(value)) return;
              setSheetState(() {
                envEntries.add(value);
                envController.clear();
              });
            }

            void addCustomFile() {
              final relativePath = filePathController.text.trim().replaceAll('\\', '/');
              final description = fileDescriptionController.text.trim();
              final contents = fileContentsController.text;
              if (relativePath.isEmpty) return;
              setSheetState(() {
                customFiles.add(
                  _TemplateSeedFile(
                    relativePath: relativePath,
                    description: description.isEmpty ? 'Custom file' : description,
                    contents: contents,
                  ),
                );
                filePathController.clear();
                fileDescriptionController.clear();
                fileContentsController.clear();
              });
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 12,
                right: 12,
                top: 12,
                bottom: MediaQuery.of(context).viewInsets.bottom + 12,
              ),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: theme.colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: theme.colorScheme.outlineVariant),
                ),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isEditing ? 'Edit template' : 'Create template',
                        style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Build a reusable Launch tile with your own image, base name, and mount layout. /misc is always included automatically.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                        ),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: imageController,
                        decoration: InputDecoration(
                          labelText: 'Docker image',
                          border: const OutlineInputBorder(),
                          suffixIcon: IconButton(
                            tooltip: 'Paste image',
                              onPressed: () async {
                                final data = await Clipboard.getData(Clipboard.kTextPlain);
                                final parsed = _extractImageFromPaste(data?.text ?? '') ?? (data?.text ?? '').trim();
                                if (parsed.isEmpty) return;
                                setSheetState(() {
                                imageController.text = parsed;
                                if (labelController.text.trim().isEmpty) {
                                  labelController.text = _titleFromImage(parsed);
                                }
                                if (baseNameController.text.trim().isEmpty) {
                                  baseNameController.text = _templateNameFromImage(parsed);
                                }
                                if (descriptionController.text.trim().isEmpty) {
                                  descriptionController.text = parsed;
                                }
                                if (parsed.toLowerCase().contains('tailscale')) {
                                  if (!mountTargets.contains('/var/lib/tailscale')) {
                                    mountTargets
                                      ..clear()
                                      ..add('/var/lib/tailscale');
                                  }
                                  if (_envValue(envEntries, 'TS_STATE_DIR') == null) {
                                    envEntries.add('TS_STATE_DIR=/var/lib/tailscale');
                                  }
                                  if (_envValue(envEntries, 'TS_USERSPACE') == null) {
                                    envEntries.add('TS_USERSPACE=true');
                                  }
                                  syncTailscaleEnv();
                                }
                              });
                            },
                            icon: const Icon(Icons.content_paste_rounded),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: labelController,
                              decoration: const InputDecoration(
                                labelText: 'Template label',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          SizedBox(
                            width: 110,
                            child: TextField(
                              controller: portController,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                labelText: 'Port',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: baseNameController,
                              decoration: const InputDecoration(
                                labelText: 'Base name',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: TextField(
                              controller: subtitleController,
                              decoration: const InputDecoration(
                                labelText: 'Category',
                                border: OutlineInputBorder(),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: descriptionController,
                        minLines: 2,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'Description',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Mounts',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          ...mountTargets.map(
                            (target) => InputChip(
                              label: Text(target),
                              onDeleted: () {
                                setSheetState(() {
                                  mountTargets.remove(target);
                                });
                              },
                            ),
                          ),
                          const _MetaPill(label: '/misc (automatic)'),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: mountController,
                              decoration: const InputDecoration(
                                labelText: 'Add mount target',
                                hintText: '/data',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => addMountTarget(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: addMountTarget,
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Comparison tags',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      if (comparisonTags.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: comparisonTags
                              .map(
                                (tag) => InputChip(
                                  label: Text(tag),
                                  onDeleted: () {
                                    setSheetState(() {
                                      comparisonTags.remove(tag);
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      if (comparisonTags.isNotEmpty) const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: comparisonController,
                              decoration: const InputDecoration(
                                labelText: 'Add comparison',
                                hintText: 'GitHub',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => addComparisonTag(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: addComparisonTag,
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      if (isTailscaleDraft()) ...[
                        const SizedBox(height: 12),
                        Text(
                          'Tailscale routing',
                          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                        ),
                        const SizedBox(height: 6),
                        TextField(
                          controller: subnetController,
                          enabled: !advertiseAllSubnets,
                          decoration: const InputDecoration(
                            labelText: 'Advertised subnet routes',
                            hintText: '192.168.1.0/24',
                            helperText: 'Comma-separate multiple routes if needed.',
                            border: OutlineInputBorder(),
                          ),
                          onChanged: (_) {
                            setSheetState(syncTailscaleEnv);
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Advertise all private subnets'),
                          subtitle: Text(
                            _allPrivateSubnetRoutes,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                            ),
                          ),
                          value: advertiseAllSubnets,
                          onChanged: (value) {
                            setSheetState(() {
                              advertiseAllSubnets = value;
                              syncTailscaleEnv();
                            });
                          },
                        ),
                        const SizedBox(height: 8),
                        SwitchListTile.adaptive(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Advertise as exit node'),
                          subtitle: const Text(
                            'Lets other Tailscale devices route internet traffic through this node.',
                          ),
                          value: advertiseExitNode,
                          onChanged: (value) {
                            setSheetState(() {
                              advertiseExitNode = value;
                              syncTailscaleEnv();
                            });
                          },
                        ),
                      ],
                      const SizedBox(height: 12),
                      Text(
                        'Environment',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      if (envEntries.isNotEmpty)
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: envEntries
                              .map(
                                (entry) => InputChip(
                                  label: Text(entry),
                                  onDeleted: () {
                                    setSheetState(() {
                                      envEntries.remove(entry);
                                    });
                                  },
                                ),
                              )
                              .toList(),
                        ),
                      if (envEntries.isNotEmpty) const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: envController,
                              decoration: const InputDecoration(
                                labelText: 'Add env var',
                                hintText: 'TS_EXTRA_ARGS=--advertise-routes=192.168.1.0/24',
                                border: OutlineInputBorder(),
                              ),
                              onSubmitted: (_) => addEnvEntry(),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.tonal(
                            onPressed: addEnvEntry,
                            child: const Text('Add'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'Custom files',
                        style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 6),
                      if (customFiles.isNotEmpty)
                        Column(
                          children: customFiles
                              .asMap()
                              .entries
                              .map(
                                (entry) => Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: theme.colorScheme.outlineVariant),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              entry.value.relativePath,
                                              style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w700),
                                            ),
                                            const SizedBox(height: 2),
                                            Text(
                                              entry.value.description,
                                              style: theme.textTheme.bodySmall?.copyWith(
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        tooltip: 'Remove file',
                                        onPressed: () {
                                          setSheetState(() {
                                            customFiles.removeAt(entry.key);
                                          });
                                        },
                                        icon: const Icon(Icons.delete_outline_rounded),
                                      ),
                                    ],
                                  ),
                                ),
                              )
                              .toList(),
                        ),
                      TextField(
                        controller: filePathController,
                        decoration: const InputDecoration(
                          labelText: 'Relative file path',
                          hintText: 'config/config.json',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fileDescriptionController,
                        decoration: const InputDecoration(
                          labelText: 'File description',
                          hintText: 'Element web config',
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: fileContentsController,
                        minLines: 4,
                        maxLines: 8,
                        decoration: const InputDecoration(
                          labelText: 'File contents',
                          alignLabelWithHint: true,
                          border: OutlineInputBorder(),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.tonal(
                          onPressed: addCustomFile,
                          child: const Text('Add file'),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          TextButton(
                            onPressed: () => Navigator.of(context).pop(),
                            child: const Text('Cancel'),
                          ),
                          const Spacer(),
                          FilledButton.icon(
                            onPressed: () {
                              final image = imageController.text.trim();
                              final label = labelController.text.trim();
                              final baseName = baseNameController.text.trim();
                              final subtitle = subtitleController.text.trim();
                              final description = descriptionController.text.trim();
                              final port = int.tryParse(portController.text.trim()) ?? 80;

                                if (image.isEmpty || label.isEmpty || baseName.isEmpty) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(content: Text('Image, label, and base name are required.')),
                                );
                                return;
                              }

                              if (isTailscaleDraft()) {
                                syncTailscaleEnv();
                              }

                              final template = _TemplateCardModel(
                                label: label,
                                subtitle: subtitle.isEmpty ? 'Custom Template' : subtitle,
                                description: description.isEmpty ? image : description,
                                comparableTo: List<String>.from(comparisonTags),
                                name: _templateNameFromImage(baseName),
                                image: image,
                                port: port <= 0 ? 80 : port,
                                icon: Icons.auto_awesome_motion_rounded,
                                accent: const Color(0xFFA0C4FF),
                                env: List<String>.from(envEntries),
                                seedFiles: List<_TemplateSeedFile>.from(customFiles),
                                mountTargets: [...mountTargets, '/misc'],
                              );

                              _registerCustomTemplate(template);
                              Navigator.of(context).pop();
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('${isEditing ? 'Updated' : 'Saved'} template ${template.label}.'),
                                  behavior: SnackBarBehavior.floating,
                                ),
                              );
                            },
                            icon: const Icon(Icons.add_box_outlined),
                            label: Text(isEditing ? 'Update template' : 'Save template'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  } finally {
    imageController.dispose();
    labelController.dispose();
    baseNameController.dispose();
    portController.dispose();
    subtitleController.dispose();
    descriptionController.dispose();
    comparisonController.dispose();
    mountController.dispose();
    envController.dispose();
    subnetController.dispose();
    filePathController.dispose();
    fileDescriptionController.dispose();
    fileContentsController.dispose();
  }
}

Widget _templateDetailRow(BuildContext context, String label, String value) {
  final theme = Theme.of(context);
  return Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 92,
          child: Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.66),
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
          ),
        ),
      ],
    ),
  );
}

Future<_TemplateLaunchConfig?> _showLaunchFlowSheet(
  BuildContext context, {
  required String title,
  required String initialName,
  required List<GoServiceDefinitionMount> Function(String serviceName, String? selectedRoot) mountBuilder,
  required List<String> env,
  String? subtitle,
  String? imageLabel,
  Widget? leadingIcon,
}) async {
  final existingDataOptions = _existingDataOptions(context);
  final nameController = TextEditingController(text: initialName);
  String? selectedRoot;

  final result = await showModalBottomSheet<_TemplateLaunchConfig>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      final theme = Theme.of(context);
      return StatefulBuilder(
        builder: (context, setSheetState) {
          return Padding(
            padding: EdgeInsets.only(
              left: 12,
              right: 12,
              top: 12,
              bottom: MediaQuery.of(context).viewInsets.bottom + 12,
            ),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surface,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: theme.colorScheme.outlineVariant),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (leadingIcon != null) ...[
                        leadingIcon,
                        const SizedBox(width: 10),
                      ],
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
                            ),
                            if (subtitle != null) ...[
                              const SizedBox(height: 2),
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (imageLabel != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      imageLabel,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(
                      labelText: 'Instance name',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String?>(
                    value: selectedRoot,
                    decoration: const InputDecoration(
                      labelText: 'Data folder',
                      border: OutlineInputBorder(),
                    ),
                    items: [
                      const DropdownMenuItem<String?>(
                        value: null,
                        child: Text('Create new managed data folder'),
                      ),
                      ...existingDataOptions.map(
                        (option) => DropdownMenuItem<String?>(
                          value: option.rootPath,
                          child: Text(option.label, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: (value) {
                      setSheetState(() {
                        selectedRoot = value;
                      });
                    },
                  ),
                  const SizedBox(height: 10),
                  Text(
                    selectedRoot == null
                        ? 'Serva will create a new managed folder under Documents\\Serva.'
                        : 'Serva will bind this template to the existing folder structure.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.68),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Cancel'),
                      ),
                      const Spacer(),
                      FilledButton(
                        onPressed: () {
                          final serviceName = nameController.text.trim();
                          if (serviceName.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('Please enter an instance name.')),
                            );
                            return;
                          }

                          Navigator.of(context).pop(
                            _TemplateLaunchConfig(
                              serviceName: serviceName,
                              mounts: mountBuilder(serviceName, selectedRoot),
                              env: env,
                            ),
                          );
                        },
                        child: const Text('Launch'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );

  nameController.dispose();
  return result;
}

String? _envValue(List<String> envEntries, String key) {
  for (final entry in envEntries) {
    final prefix = '$key=';
    if (entry.startsWith(prefix)) {
      return entry.substring(prefix.length);
    }
  }
  return null;
}

String _extractAdvertisedRoutes(String extraArgs) {
  final match = RegExp(r'--advertise-routes=([^\s]+)').firstMatch(extraArgs);
  return match?.group(1) ?? '';
}

bool _containsExitNodeFlag(String extraArgs) {
  return extraArgs.split(RegExp(r'\s+')).contains('--advertise-exit-node');
}

const String _allPrivateSubnetRoutes = '10.0.0.0/8,172.16.0.0/12,192.168.0.0/16';

bool _isAllPrivateSubnetSet(String routes) {
  final normalized = routes
      .split(',')
      .map((route) => route.trim())
      .where((route) => route.isNotEmpty)
      .toList()
    ..sort();
  final expected = _allPrivateSubnetRoutes
      .split(',')
      .map((route) => route.trim())
      .where((route) => route.isNotEmpty)
      .toList()
    ..sort();
  if (normalized.length != expected.length) return false;
  for (var i = 0; i < normalized.length; i++) {
    if (normalized[i] != expected[i]) return false;
  }
  return true;
}
