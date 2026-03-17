part of '../homescreen.dart';

class _CreateServiceSheet extends StatefulWidget {
  const _CreateServiceSheet({required this.bloc});

  final MainBloc bloc;

  @override
  State<_CreateServiceSheet> createState() => _CreateServiceSheetState();
}

class _CreateServiceSheetState extends State<_CreateServiceSheet> {
  final _nameCtrl = TextEditingController();
  final _imageCtrl = TextEditingController();
  final _portCtrl = TextEditingController(text: '80');
  final _formKey = GlobalKey<FormState>();
  final _mountSourceCtrl = TextEditingController();
  final _mountTargetCtrl = TextEditingController();
  final List<GoServiceDefinitionMount> _mounts = [];

  int _selectedTemplate = 0;
  bool _mountReadOnly = false;
  bool _mountManaged = true;
  String _mountType = 'bind';

  String get _defaultManagedBasePath {
    final userProfile = Platform.environment['USERPROFILE'];
    if (userProfile != null && userProfile.trim().isNotEmpty) {
      return '$userProfile\\Documents\\Serva';
    }

    final home = Platform.environment['HOME'];
    if (home != null && home.trim().isNotEmpty) {
      return '$home${Platform.pathSeparator}Documents${Platform.pathSeparator}Serva';
    }

    return 'Documents${Platform.pathSeparator}Serva';
  }

  @override
  void initState() {
    super.initState();
    _applyTemplate(_selectedTemplate);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _imageCtrl.dispose();
    _portCtrl.dispose();
    _mountSourceCtrl.dispose();
    _mountTargetCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, top: 12, bottom: 16 + bottomPadding),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Text('Create service', style: Theme.of(context).textTheme.titleLarge),
              ),
              IconButton(
                tooltip: 'Docker Hub',
                onPressed: _openDockerHubSearch,
                icon: const Icon(Icons.travel_explore),
              ),
              IconButton(
                tooltip: 'Paste image/command',
                onPressed: _pasteImageOrCommand,
                icon: const Icon(Icons.content_paste),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _buildTemplatePicker(),
          const SizedBox(height: 12),
          _buildBasicsForm(),
          const SizedBox(height: 16),
          Text('Persistent mounts', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          _buildSavedMountsList(),
          _buildMountDraftForm(),
          const SizedBox(height: 16),
          _buildFooterActions(),
        ],
      ),
    );
  }
}
