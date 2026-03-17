part of '../service_details_sheet.dart';

Future<void> showServiceDetailsSheet(BuildContext context, GoService service) async {
  final bloc = context.read<MainBloc>();

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => FractionallySizedBox(
      heightFactor: 0.92,
      child: _ServiceDetailsSheet(service: service, bloc: bloc),
    ),
  );
}

class _ServiceDetailsSheet extends StatefulWidget {
  const _ServiceDetailsSheet({required this.service, required this.bloc});

  final GoService service;
  final MainBloc bloc;

  @override
  State<_ServiceDetailsSheet> createState() => _ServiceDetailsSheetState();
}

class _ServiceDetailsSheetState extends State<_ServiceDetailsSheet> {
  final ServaApi _api = ServaApi();

  late Future<_ServiceDetailsData> _future;

  bool get _isRunning => widget.service.state.toLowerCase() == 'running';

  @override
  void initState() {
    super.initState();
    _future = _loadDetails();
  }

  Future<_ServiceDetailsData> _loadDetails() async {
    final inspect = await _api.serviceInspect(widget.service.id);
    final stats = await _api.serviceStats(widget.service.id);
    final logs = await _api.serviceLogs(widget.service.id);
    return _ServiceDetailsData(inspect: inspect, stats: stats, logs: logs);
  }

  void _refresh() {
    setState(() {
      _future = _loadDetails();
    });
  }

  Future<void> _confirmRemove() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Remove service?'),
        content: Text('This will force-remove "${widget.service.name}".'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Remove')),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      Navigator.of(context).pop();
      widget.bloc.add(MainRemoveRequested(id: widget.service.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.service.name, style: Theme.of(context).textTheme.titleLarge),
                    const SizedBox(height: 4),
                    Text(widget.service.image, style: Theme.of(context).textTheme.bodyMedium),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Refresh details',
                onPressed: _refresh,
                icon: const Icon(Icons.refresh),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildActionBar(),
          const SizedBox(height: 16),
          Expanded(
            child: FutureBuilder<_ServiceDetailsData>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState != ConnectionState.done) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return _DetailErrorView(
                    message: snapshot.error.toString(),
                    onRetry: _refresh,
                  );
                }

                final data = snapshot.data;
                if (data == null) {
                  return _DetailErrorView(
                    message: 'No details available.',
                    onRetry: _refresh,
                  );
                }

                return ListView(children: _buildDetailSections(context, data));
              },
            ),
          ),
        ],
      ),
    );
  }
}
