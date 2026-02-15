import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sovereign/api/sovereign_api.dart';

import 'main_event.dart';
import 'main_state.dart';

class MainBloc extends Bloc<MainEvent, MainState> {
  MainBloc({required SovereignApi api}) : _api = api, super(const MainInitial()) {
    on<MainLoadRequested>(_onLoad);
    on<MainCreateTestRequested>(_onCreateTest);
    on<MainStartRequested>(_onStart);
    on<MainStopRequested>(_onStop);

    // Kick off an initial load.
    add(const MainLoadRequested());
  }

  final SovereignApi _api;

  Future<void> _onLoad(MainLoadRequested event, Emitter<MainState> emit) async {
    // Keep any existing services visible while refreshing.
    final previous = state;
    if (previous is MainLoaded) {
      emit(MainLoading(message: 'Refreshing…'));
    } else {
      emit(const MainLoading(message: 'Loading…'));
    }

    try {
      final health = await _api.health();
      final services = await _api.listServices();

      emit(MainLoaded(services: services, healthOk: health.ok));
    } catch (e) {
      // If we already had a loaded state, fall back to showing it with a message.
      if (previous is MainLoaded) {
        emit(MainLoaded(services: previous.services, healthOk: previous.healthOk, lastMessage: 'Refresh failed: $e'));
        return;
      }

      emit(MainError(message: e.toString()));
    }
  }

  Future<void> _onCreateTest(MainCreateTestRequested event, Emitter<MainState> emit) async {
    emit(const MainLoading(message: 'Creating test service…'));

    try {
      await _api.createTestService();
      // Reload list so port/urls are up to date.
      final health = await _api.health();
      final services = await _api.listServices();

      emit(MainLoaded(services: services, healthOk: health.ok, lastMessage: 'Created test service.'));
    } catch (e) {
      emit(MainError(message: e.toString()));
    }
  }

  Future<void> _onStart(MainStartRequested event, Emitter<MainState> emit) async {
    final previous = state;
    emit(const MainLoading(message: 'Starting…'));

    try {
      await _api.startService(event.id);
      final services = await _api.listServices();

      // Preserve previous health flag if available.
      final healthOk = (previous is MainLoaded) ? previous.healthOk : true;

      emit(MainLoaded(services: services, healthOk: healthOk, lastMessage: 'Started.'));
    } catch (e) {
      if (previous is MainLoaded) {
        emit(MainLoaded(services: previous.services, healthOk: previous.healthOk, lastMessage: 'Start failed: $e'));
        return;
      }
      emit(MainError(message: e.toString()));
    }
  }

  Future<void> _onStop(MainStopRequested event, Emitter<MainState> emit) async {
    final previous = state;
    emit(const MainLoading(message: 'Stopping…'));

    try {
      await _api.stopService(event.id);
      final services = await _api.listServices();

      final healthOk = (previous is MainLoaded) ? previous.healthOk : true;

      emit(MainLoaded(services: services, healthOk: healthOk, lastMessage: 'Stopped.'));
    } catch (e) {
      if (previous is MainLoaded) {
        emit(MainLoaded(services: previous.services, healthOk: previous.healthOk, lastMessage: 'Stop failed: $e'));
        return;
      }
      emit(MainError(message: e.toString()));
    }
  }
}
