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
    mountBuilder: (serviceName, selectedRoot) => _defaultMountsForTemplate(
      template.name,
      serviceName,
      rootOverride: selectedRoot,
    ),
    env: template.env,
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
    mountBuilder: (serviceName, selectedRoot) => _defaultMountsForTemplate(
      'custom',
      serviceName,
      rootOverride: selectedRoot,
    ),
    env: const [],
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
