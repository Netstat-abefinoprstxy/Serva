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

/// Create a managed service with the given docker image and container port.
class MainCreateServiceRequested extends MainEvent {
  const MainCreateServiceRequested({required this.name, required this.image, this.containerPort = 80});

  final String name;
  final String image;
  final int containerPort;
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

/// Expose or un-expose a managed service to the local network (LAN).
class MainExposeLanRequested extends MainEvent {
  const MainExposeLanRequested({required this.id, this.enabled = true});

  final String id;
  final bool enabled;
}
