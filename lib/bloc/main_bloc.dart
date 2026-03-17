import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:serva/api/go_models.dart';
import 'package:serva/api/sovereign_api.dart';

import 'main_event.dart';
import 'main_state.dart';

class MainBloc extends Bloc<MainEvent, MainState> {
  MainBloc({required ServaApi api}) : _api = api, super(const MainInitial()) {
    on<MainLoadRequested>(_onLoad);
    on<MainCreateTestRequested>(_onCreateTest);
    on<MainCreateServiceRequested>(_onCreateService);
    on<MainStartRequested>(_onStart);
    on<MainStopRequested>(_onStop);
    on<MainRestartRequested>(_onRestart);
    on<MainRemoveRequested>(_onRemove);
    on<MainRecreateRequested>(_onRecreate);
    on<MainDeleteDefinitionRequested>(_onDeleteDefinition);
    on<MainExposeLanRequested>(_onExposeLan);

    add(const MainLoadRequested());
  }

  final ServaApi _api;

  Future<_Snapshot> _fetchSnapshot() async {
    final health = await _api.health();
    final services = await _api.listServices();
    final definitions = await _api.listServiceDefinitions();
    return _Snapshot(services: services, definitions: definitions, healthOk: health.ok);
  }

  MainLoaded _loadedFromSnapshot(_Snapshot snapshot, {String? lastMessage}) {
    return MainLoaded(
      services: snapshot.services,
      definitions: snapshot.definitions,
      healthOk: snapshot.healthOk,
      lastMessage: lastMessage,
    );
  }

  Future<void> _onLoad(MainLoadRequested event, Emitter<MainState> emit) async {
    final previous = state;
    emit(MainLoading(message: previous is MainLoaded ? 'Refreshing...' : 'Loading...'));

    try {
      final snapshot = await _fetchSnapshot();
      emit(_loadedFromSnapshot(snapshot));
    } catch (e) {
      if (previous is MainLoaded) {
        emit(
          MainLoaded(
            services: previous.services,
            definitions: previous.definitions,
            healthOk: previous.healthOk,
            lastMessage: 'Refresh failed: $e',
          ),
        );
        return;
      }

      emit(MainError(message: e.toString()));
    }
  }

  Future<void> _runAction(
    Emitter<MainState> emit, {
    required String loadingMessage,
    required Future<void> Function() action,
    required String successMessage,
    required String failurePrefix,
  }) async {
    final previous = state;
    emit(MainLoading(message: loadingMessage));

    try {
      await action();
      final snapshot = await _fetchSnapshot();
      emit(_loadedFromSnapshot(snapshot, lastMessage: successMessage));
    } catch (e) {
      if (previous is MainLoaded) {
        emit(
          MainLoaded(
            services: previous.services,
            definitions: previous.definitions,
            healthOk: previous.healthOk,
            lastMessage: '$failurePrefix: $e',
          ),
        );
        return;
      }

      emit(MainError(message: e.toString()));
    }
  }

  Future<void> _onCreateTest(MainCreateTestRequested event, Emitter<MainState> emit) async {
    await _runAction(
      emit,
      loadingMessage: 'Creating test service...',
      action: () async {
        await _api.createTestService();
      },
      successMessage: 'Created test service.',
      failurePrefix: 'Create test failed',
    );
  }

  Future<void> _onCreateService(MainCreateServiceRequested event, Emitter<MainState> emit) async {
    await _runAction(
      emit,
      loadingMessage: 'Creating service...',
      action: () async {
        await _api.createService(
          name: event.name,
          image: event.image,
          containerPort: event.containerPort,
          mounts: event.mounts,
        );
      },
      successMessage: 'Created ${event.name}.',
      failurePrefix: 'Create failed',
    );
  }

  Future<void> _onStart(MainStartRequested event, Emitter<MainState> emit) async {
    await _runAction(
      emit,
      loadingMessage: 'Starting...',
      action: () async {
        await _api.startService(event.id);
      },
      successMessage: 'Started.',
      failurePrefix: 'Start failed',
    );
  }

  Future<void> _onStop(MainStopRequested event, Emitter<MainState> emit) async {
    await _runAction(
      emit,
      loadingMessage: 'Stopping...',
      action: () async {
        await _api.stopService(event.id);
      },
      successMessage: 'Stopped.',
      failurePrefix: 'Stop failed',
    );
  }

  Future<void> _onRestart(MainRestartRequested event, Emitter<MainState> emit) async {
    await _runAction(
      emit,
      loadingMessage: 'Restarting...',
      action: () async {
        await _api.restartService(event.id);
      },
      successMessage: 'Restarted.',
      failurePrefix: 'Restart failed',
    );
  }

  Future<void> _onRemove(MainRemoveRequested event, Emitter<MainState> emit) async {
    await _runAction(
      emit,
      loadingMessage: 'Removing service...',
      action: () async {
        await _api.removeService(event.id);
      },
      successMessage: 'Removed container. Definition saved.',
      failurePrefix: 'Remove failed',
    );
  }

  Future<void> _onRecreate(MainRecreateRequested event, Emitter<MainState> emit) async {
    await _runAction(
      emit,
      loadingMessage: 'Recreating service...',
      action: () async {
        await _api.recreateService(event.id);
      },
      successMessage: 'Recreated service.',
      failurePrefix: 'Recreate failed',
    );
  }

  Future<void> _onDeleteDefinition(MainDeleteDefinitionRequested event, Emitter<MainState> emit) async {
    await _runAction(
      emit,
      loadingMessage: event.deleteData ? 'Deleting definition and data...' : 'Deleting definition...',
      action: () async {
        await _api.deleteServiceDefinition(event.id, deleteData: event.deleteData);
      },
      successMessage: event.deleteData ? 'Deleted definition and managed data.' : 'Deleted definition.',
      failurePrefix: 'Delete definition failed',
    );
  }

  Future<void> _onExposeLan(MainExposeLanRequested event, Emitter<MainState> emit) async {
    await _runAction(
      emit,
      loadingMessage: 'Updating LAN exposure...',
      action: () async {
        await _api.exposeServiceLan(event.id, enabled: event.enabled);
      },
      successMessage: event.enabled ? 'Service exposed to LAN.' : 'LAN exposure disabled.',
      failurePrefix: 'Expose to LAN failed',
    );
  }
}

class _Snapshot {
  const _Snapshot({
    required this.services,
    required this.definitions,
    required this.healthOk,
  });

  final List<GoService> services;
  final List<GoServiceDefinition> definitions;
  final bool healthOk;
}
