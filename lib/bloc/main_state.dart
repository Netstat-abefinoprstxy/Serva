import 'package:serva/api/go_models.dart';

/// Base type for MainBloc states.
abstract class MainState {
  const MainState();
}

/// Initial/idle state.
class MainInitial extends MainState {
  const MainInitial();
}

/// Shows an in-progress operation.
class MainLoading extends MainState {
  const MainLoading({this.message});
  final String? message;
}

/// Successfully loaded services.
class MainLoaded extends MainState {
  const MainLoaded({
    required this.services,
    required this.definitions,
    required this.healthOk,
    this.lastMessage,
  });

  final List<GoService> services;
  final List<GoServiceDefinition> definitions;
  final bool healthOk;
  final String? lastMessage;
}

/// A recoverable error.
class MainError extends MainState {
  const MainError({required this.message});
  final String message;
}
