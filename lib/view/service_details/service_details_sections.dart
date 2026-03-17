part of '../service_details_sheet.dart';

extension _ServiceDetailsSections on _ServiceDetailsSheetState {
  Widget _buildActionBar() {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        if (widget.service.localUrl.trim().isNotEmpty)
          FilledButton.tonalIcon(
            onPressed: () => _openUrl(context, widget.service.localUrl),
            icon: const Icon(Icons.open_in_new),
            label: const Text('Open local'),
          ),
        if (widget.service.lanUrl.trim().isNotEmpty)
          FilledButton.tonalIcon(
            onPressed: () => _openUrl(context, widget.service.lanUrl),
            icon: const Icon(Icons.wifi),
            label: const Text('Open LAN'),
          ),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.bloc.add(MainRestartRequested(id: widget.service.id));
          },
          icon: const Icon(Icons.restart_alt),
          label: const Text('Restart'),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).pop();
            if (_isRunning) {
              widget.bloc.add(MainStopRequested(id: widget.service.id));
            } else {
              widget.bloc.add(MainStartRequested(id: widget.service.id));
            }
          },
          icon: Icon(_isRunning ? Icons.stop : Icons.play_arrow),
          label: Text(_isRunning ? 'Stop' : 'Start'),
        ),
        FilledButton.tonalIcon(
          onPressed: () {
            Navigator.of(context).pop();
            widget.bloc.add(MainExposeLanRequested(id: widget.service.id, enabled: !widget.service.lanEnabled));
          },
          icon: const Icon(Icons.settings_ethernet),
          label: Text(widget.service.lanEnabled ? 'Disable LAN' : 'Enable LAN'),
        ),
        FilledButton.tonalIcon(
          onPressed: _confirmRemove,
          icon: const Icon(Icons.delete_outline),
          label: const Text('Remove'),
        ),
      ],
    );
  }

  List<Widget> _buildDetailSections(BuildContext context, _ServiceDetailsData data) {
    return [
      _DetailSection(
        title: 'Overview',
        child: Column(
          children: [
            _DetailRow(label: 'State', value: data.inspect.state),
            _DetailRow(label: 'Status', value: data.inspect.status),
            _DetailRow(label: 'Container ID', value: _shortId(data.inspect.id)),
            _DetailRow(label: 'Created', value: data.inspect.created),
            _DetailRow(label: 'Restart policy', value: data.inspect.restartPolicy.isEmpty ? 'none' : data.inspect.restartPolicy),
            _DetailRow(label: 'Path', value: data.inspect.path),
            if (data.inspect.localUrl.trim().isNotEmpty) _DetailRow(label: 'Local URL', value: data.inspect.localUrl),
            if (data.inspect.lanUrl.trim().isNotEmpty) _DetailRow(label: 'LAN URL', value: data.inspect.lanUrl),
          ],
        ),
      ),
      _DetailSection(
        title: 'Ports',
        child: data.inspect.ports.isEmpty
            ? const Text('No published ports.')
            : Column(
                children: data.inspect.ports
                    .map(
                      (port) => _DetailRow(
                        label: port.containerRef,
                        value: port.publicPort > 0 ? '${port.ip.isEmpty ? '0.0.0.0' : port.ip}:${port.publicPort}' : 'container-only',
                      ),
                    )
                    .toList(),
              ),
      ),
      _DetailSection(
        title: 'Stats',
        child: Column(
          children: [
            _DetailRow(label: 'Read at', value: data.stats.readAt.isEmpty ? 'n/a' : data.stats.readAt),
            _DetailRow(label: 'CPU total', value: _nestedValueAsString(data.stats.raw, const ['cpu_stats', 'cpu_usage', 'total_usage'])),
            _DetailRow(label: 'Memory usage', value: _nestedValueAsString(data.stats.raw, const ['memory_stats', 'usage'])),
            _DetailRow(label: 'Memory limit', value: _nestedValueAsString(data.stats.raw, const ['memory_stats', 'limit'])),
            _DetailRow(label: 'Network rx bytes', value: _sumNestedMapField(data.stats.raw['networks'], 'rx_bytes')),
            _DetailRow(label: 'Network tx bytes', value: _sumNestedMapField(data.stats.raw['networks'], 'tx_bytes')),
          ],
        ),
      ),
      _DetailSection(
        title: 'Logs',
        trailing: IconButton(
          tooltip: 'Copy logs',
          onPressed: () async {
            await Clipboard.setData(ClipboardData(text: data.logs.logs));
            if (!context.mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Logs copied')));
          },
          icon: const Icon(Icons.copy_all),
        ),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(12),
          ),
          child: SelectableText(
            data.logs.logs.trim().isEmpty ? 'No logs returned.' : data.logs.logs,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(fontFamily: 'Courier'),
          ),
        ),
      ),
      _DetailSection(
        title: 'Environment',
        child: data.inspect.env.isEmpty
            ? const Text('No environment variables reported.')
            : Column(children: data.inspect.env.map((entry) => _DetailRow(label: 'ENV', value: entry)).toList()),
      ),
      _DetailSection(
        title: 'Mounts',
        child: data.inspect.mounts.isEmpty
            ? const Text('No mounts reported.')
            : Column(
                children: data.inspect.mounts
                    .map(
                      (mount) => _DetailRow(
                        label: mount.destination,
                        value: '${mount.source} (${mount.type}${mount.readOnly ? ', read-only' : ''})',
                        trailing: mount.type.toLowerCase() == 'bind'
                            ? IconButton(
                                tooltip: 'Open folder',
                                onPressed: () => _openDirectory(context, mount.source),
                                icon: const Icon(Icons.folder_open),
                              )
                            : null,
                      ),
                    )
                    .toList(),
              ),
      ),
      _DetailSection(
        title: 'Labels',
        child: data.inspect.labels.isEmpty
            ? const Text('No labels reported.')
            : Column(
                children: data.inspect.labels.entries.map((entry) => _DetailRow(label: entry.key, value: entry.value)).toList(),
              ),
      ),
      const SizedBox(height: 32),
    ];
  }
}
