part of '../template_gallery_screen.dart';

class _TemplateTile extends StatelessWidget {
  const _TemplateTile({required this.template});

  final _TemplateCardModel template;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseSurface = theme.colorScheme.surfaceContainerHigh;
    final titleColor = theme.colorScheme.onSurface;
    final bodyColor = titleColor.withValues(alpha: 0.74);
    final isVerified = TemplateGalleryScreen.verifiedTemplateKeys.value.contains(_templateKey(template));

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: () => _createFromTemplate(context, template),
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(template.accent.withValues(alpha: 0.08), baseSurface),
                Color.alphaBlend(template.accent.withValues(alpha: 0.18), theme.colorScheme.surfaceContainer),
              ],
            ),
            border: Border.all(color: template.accent.withValues(alpha: 0.3)),
            boxShadow: [
              BoxShadow(
                color: template.accent.withValues(alpha: 0.08),
                blurRadius: 12,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(template.icon, size: 18, color: template.accent),
                    ),
                    const Spacer(),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          tooltip: 'Template details',
                          onPressed: () => _showTemplateDetailsSheet(context, template),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          icon: Icon(
                            Icons.settings_outlined,
                            size: 18,
                            color: titleColor.withValues(alpha: 0.76),
                          ),
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          tooltip: isVerified ? 'Move to Experimental' : 'Move to Verified',
                          onPressed: () => _toggleVerified(template),
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 30, minHeight: 30),
                          icon: Icon(
                            isVerified ? Icons.verified_rounded : Icons.science_outlined,
                            size: 18,
                            color: isVerified ? const Color(0xFF80ED99) : titleColor.withValues(alpha: 0.72),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: template.accent.withValues(alpha: 0.16),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            template.subtitle.toUpperCase(),
                            style: TextStyle(
                              color: titleColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 9,
                              letterSpacing: 0.7,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  template.label,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  template.description,
                  style: TextStyle(
                    color: bodyColor,
                    fontSize: 12,
                    height: 1.2,
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _MetaPill(label: 'Port ${template.port}'),
                    ...template.comparableTo
                        .where((comparison) => comparison.trim().isNotEmpty)
                        .map((comparison) => _MetaPill(label: 'Like $comparison')),
                    const _MetaPill(label: 'Persistent'),
                  ],
                ),
                const Spacer(),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text(
                      template.subtitle,
                      style: TextStyle(
                        color: titleColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),
                    Icon(Icons.arrow_forward_rounded, size: 18, color: template.accent),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _createFromTemplate(BuildContext context, _TemplateCardModel template) async {
    final bloc = context.read<MainBloc>();
    final launchConfig = await _showTemplateLaunchFlow(context, template);
    if (launchConfig == null || !context.mounted) return;
    await _prepareTemplateFiles(template, launchConfig);
    if (!context.mounted) return;

    bloc.add(
      MainCreateServiceRequested(
        name: launchConfig.serviceName,
        image: template.image,
        containerPort: template.port,
        mounts: launchConfig.mounts,
        env: launchConfig.env,
      ),
    );

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Creating ${launchConfig.serviceName}...'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _toggleVerified(_TemplateCardModel template) {
    final current = Set<String>.from(TemplateGalleryScreen.verifiedTemplateKeys.value);
    final key = _templateKey(template);
    if (current.contains(key)) {
      current.remove(key);
    } else {
      current.add(key);
    }
    TemplateGalleryScreen.verifiedTemplateKeys.value = current;
    _persistVerifiedTemplates();
  }
}
