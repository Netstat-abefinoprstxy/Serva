/// Base type for MainBloc events.
abstract class MainEvent {
  const MainEvent();
}

/// Initial load (also used for pull-to-refresh).
class MainLoadRequested extends MainEvent {
  const MainLoadRequested();
}

/// Create the managed nginx test container.
class MainCreateTestRequested extends MainEvent {
  const MainCreateTestRequested();
}

/// Start a managed service/container by id.
class MainStartRequested extends MainEvent {
  const MainStartRequested({required this.id});
  final String id;
}

/// Stop a managed service/container by id.
class MainStopRequested extends MainEvent {
  const MainStopRequested({required this.id});
  final String id;
}
