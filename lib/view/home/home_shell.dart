part of '../homescreen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return _HomeTabbedShell(onCreateService: () => _showCreateServiceSheet(context));
  }

  void _showCreateServiceSheet(BuildContext context) {
    final bloc = context.read<MainBloc>();

    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _CreateServiceSheet(bloc: bloc),
    );
  }
}

class _HomeTabbedShell extends StatefulWidget {
  const _HomeTabbedShell({required this.onCreateService});

  final VoidCallback onCreateService;

  @override
  State<_HomeTabbedShell> createState() => _HomeTabbedShellState();
}

class _HomeTabbedShellState extends State<_HomeTabbedShell> {
  int _currentIndex = 0;
  bool _legacyModeEnabled = false;

  String get _title {
    switch (_currentIndex) {
      case 0:
        return 'Serva Dashboard';
      case 1:
        return 'Serva Services';
      case 2:
        return 'Quick Launch';
      case 3:
        return 'Serva Legacy';
      default:
        return 'Serva';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => context.read<MainBloc>().add(const MainLoadRequested()),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: BlocBuilder<MainBloc, MainState>(
        builder: (context, state) {
          MainLoaded? fallbackLoadedState;
          if (state is MainError &&
              (_looksLikeDockerUnavailable(state.message) || _looksLikeVirtualizationIssue(state.message))) {
            fallbackLoadedState = MainLoaded(
              services: const [],
              definitions: const [],
              healthOk: false,
              lastMessage: state.message,
            );
          }

          if (state is MainInitial) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is MainLoading) {
            return const _LoadingView(message: 'Loading your control plane...');
          }

          if (state is MainError && fallbackLoadedState == null) {
            return _ErrorView(
              message: state.message,
              onRetry: () => context.read<MainBloc>().add(const MainLoadRequested()),
            );
          }

          final loadedState = state is MainLoaded ? state : fallbackLoadedState;
          if (loadedState != null) {
            final pages = [
              DashboardScreen(state: loadedState),
              ServicesOverviewScreen(
                state: loadedState,
                legacyModeEnabled: _legacyModeEnabled,
                onLegacyModeChanged: (enabled) {
                  setState(() {
                    _legacyModeEnabled = enabled;
                    if (!enabled && _currentIndex > 2) {
                      _currentIndex = 2;
                    }
                  });
                },
              ),
              const TemplateGalleryScreen(),
              if (_legacyModeEnabled)
                _LoadedView(
                  state: loadedState,
                  onCreateService: widget.onCreateService,
                ),
            ];

            return IndexedStack(
              index: _currentIndex,
              children: pages,
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: _legacyModeEnabled && _currentIndex == 3
          ? FloatingActionButton.extended(
              onPressed: widget.onCreateService,
              icon: const Icon(Icons.add),
              label: const Text('Create service'),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.space_dashboard_rounded),
            selectedIcon: Icon(Icons.space_dashboard),
            label: 'Dashboard',
          ),
          const NavigationDestination(
            icon: Icon(Icons.dns_outlined),
            selectedIcon: Icon(Icons.dns_rounded),
            label: 'Services',
          ),
          const NavigationDestination(
            icon: Icon(Icons.grid_view_rounded),
            selectedIcon: Icon(Icons.grid_view),
            label: 'Launch',
          ),
          if (_legacyModeEnabled)
            const NavigationDestination(
              icon: Icon(Icons.widgets_outlined),
              selectedIcon: Icon(Icons.widgets_rounded),
              label: 'Legacy',
            ),
        ],
      ),
    );
  }
}
