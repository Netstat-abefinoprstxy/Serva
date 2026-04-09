part of '../homescreen.dart';

const _dockerDesktopStoreUrl = 'https://apps.microsoft.com/detail/xp8cbj40xlbwkx?hl=en-GB&gl=GB';
const _virtualizationHelpUrl =
    'https://support.microsoft.com/en-us/windows/enable-virtualization-on-windows-c5578302-6e43-4b4b-a449-8ced115f58e1';
const _forceVirtualizationHelpPreview = false;

bool _looksLikeBackendUnavailable(String? message) {
  if (message == null || message.trim().isEmpty) {
    return false;
  }

  final normalized = message.toLowerCase();
  return normalized.contains('connection refused') ||
      normalized.contains('actively refused') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('socketexception') ||
      normalized.contains('health check failed') && !normalized.contains('docker unavailable');
}

bool _looksLikeDockerUnavailable(String? message) {
  if (message == null || message.trim().isEmpty) {
    return false;
  }

  final normalized = message.toLowerCase();
  return normalized.contains('docker') ||
      normalized.contains('daemon not reachable');
}

bool _looksLikeVirtualizationIssue(String? message) {
  if (_forceVirtualizationHelpPreview) {
    return true;
  }

  if (message == null || message.trim().isEmpty) {
    return false;
  }

  final normalized = message.toLowerCase();
  return normalized.contains('virtualization') ||
      normalized.contains('hyper-v') ||
      normalized.contains('hyperv') ||
      normalized.contains('wsl') ||
      normalized.contains('bios') ||
      normalized.contains('uefi') ||
      normalized.contains('virtualization support not detected') ||
      normalized.contains('failed to start because virtualization') ||
      normalized.contains('docker desktop is unable to start') ||
      normalized.contains('hardware assisted virtualization') ||
      normalized.contains('required feature is not installed') ||
      normalized.contains('vmx') ||
      normalized.contains('svm');
}

Future<void> _openUrl(BuildContext context, String url) async {
  final trimmed = url.trim();
  if (trimmed.isEmpty) return;

  Uri? uri;
  try {
    uri = Uri.parse(trimmed);
  } catch (_) {
    uri = null;
  }

  if (uri == null) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invalid URL')));
    return;
  }

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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Could not open folder: $error')),
    );
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
