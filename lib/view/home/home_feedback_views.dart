part of '../homescreen.dart';

class _LoadingView extends StatelessWidget {
  const _LoadingView({this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 12),
          Text(message ?? 'Working...'),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final backendUnavailable = _looksLikeBackendUnavailable(message);
    final dockerUnavailable = _looksLikeDockerUnavailable(message);
    final virtualizationIssue = _looksLikeVirtualizationIssue(message);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48),
            const SizedBox(height: 12),
            Text(
              virtualizationIssue
                  ? 'Docker Desktop needs virtualization enabled to run.\n\nTurn on virtualization in Windows and, if needed, enable virtualization in your BIOS/UEFI settings first, then retry.'
                  : backendUnavailable
                  ? 'Serva could not reach its local backend service.\n\nIf you are running a debug build, start `sovereignd.exe` manually first. In packaged builds, restart Serva and retry.'
                  : dockerUnavailable
                  ? 'Docker Desktop is required before Serva can manage services.\n\nInstall or start Docker Desktop, then retry.'
                  : message,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            if (virtualizationIssue) ...[
              FilledButton.icon(
                onPressed: () => _openUrl(context, _virtualizationHelpUrl),
                icon: const Icon(Icons.memory),
                label: const Text('Enable Virtualization'),
              ),
              const SizedBox(height: 12),
            ],
            if (dockerUnavailable) ...[
              FilledButton.icon(
                onPressed: () => _openUrl(context, _dockerDesktopStoreUrl),
                icon: const Icon(Icons.download),
                label: const Text('Get Docker Desktop'),
              ),
              const SizedBox(height: 12),
            ],
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: Text(backendUnavailable ? 'Retry backend' : 'Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
