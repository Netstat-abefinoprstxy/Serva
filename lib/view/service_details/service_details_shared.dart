part of '../service_details_sheet.dart';

class _DetailErrorView extends StatelessWidget {
  const _DetailErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 40),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}

class _DetailSection extends StatelessWidget {
  const _DetailSection({required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.label,
    required this.value,
    this.trailing,
  });

  final String label;
  final String value;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            child: SelectableText(
              value,
              style: theme.textTheme.bodyMedium,
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}

class _ServiceDetailsData {
  const _ServiceDetailsData({
    required this.inspect,
    required this.stats,
    required this.logs,
  });

  final GoInspectResponse inspect;
  final GoStatsResponse stats;
  final GoLogsResponse logs;
}

Future<void> _openUrl(BuildContext context, String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;

  final uri = Uri.tryParse(trimmed);
  if (uri == null) return;

  final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
  if (!ok && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open link')));
  }
}

Future<void> _openDirectory(BuildContext context, String path) async {
  final trimmed = path.trim();
  if (trimmed.isEmpty) return;

  try {
    if (Platform.isWindows) {
      await Process.start('explorer.exe', [trimmed]);
    } else if (Platform.isMacOS) {
      await Process.start('open', [trimmed]);
    } else if (Platform.isLinux) {
      await Process.start('xdg-open', [trimmed]);
    } else {
      throw UnsupportedError('Opening folders is not supported on this platform.');
    }
  } catch (error) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not open folder: $error')));
  }
}

String _shortId(String id) => id.length <= 12 ? id : id.substring(0, 12);

String _nestedValueAsString(Map<String, dynamic> root, List<String> path) {
  dynamic current = root;
  for (final segment in path) {
    if (current is Map<String, dynamic>) {
      current = current[segment];
    } else if (current is Map) {
      current = current[segment];
    } else {
      return 'n/a';
    }
  }

  return current?.toString() ?? 'n/a';
}

String _sumNestedMapField(dynamic raw, String field) {
  if (raw is! Map) return 'n/a';

  var total = 0.0;
  var found = false;
  for (final value in raw.values) {
    if (value is Map && value[field] is num) {
      total += (value[field] as num).toDouble();
      found = true;
    }
  }

  if (!found) return 'n/a';
  return total % 1 == 0 ? total.toInt().toString() : total.toStringAsFixed(2);
}
