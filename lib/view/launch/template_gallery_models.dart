part of '../template_gallery_screen.dart';

class _TemplateLaunchConfig {
  const _TemplateLaunchConfig({
    required this.serviceName,
    required this.mounts,
    required this.env,
  });

  final String serviceName;
  final List<GoServiceDefinitionMount> mounts;
  final List<String> env;
}

class _ExistingDataOption {
  const _ExistingDataOption({
    required this.rootPath,
    required this.label,
  });

  final String rootPath;
  final String label;
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: theme.colorScheme.onSurface,
          fontWeight: FontWeight.w600,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _TemplateCardModel {
  const _TemplateCardModel({
    required this.label,
    required this.subtitle,
    required this.description,
    required this.name,
    required this.image,
    required this.port,
    required this.icon,
    required this.accent,
    this.env = const [],
  });

  final String label;
  final String subtitle;
  final String description;
  final String name;
  final String image;
  final int port;
  final IconData icon;
  final Color accent;
  final List<String> env;
}
