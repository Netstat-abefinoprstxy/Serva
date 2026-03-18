import 'package:serva/api/go_models.dart';

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
  const MainCreateServiceRequested({
    required this.name,
    required this.image,
    this.containerPort = 80,
    this.mounts = const [],
    this.env = const [],
  });

  final String name;
  final String image;
  final int containerPort;
  final List<GoServiceDefinitionMount> mounts;
  final List<String> env;
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

class MainRestartRequested extends MainEvent {
  const MainRestartRequested({required this.id});
  final String id;
}

class MainRemoveRequested extends MainEvent {
  const MainRemoveRequested({required this.id});
  final String id;
}

class MainRecreateRequested extends MainEvent {
  const MainRecreateRequested({required this.id});
  final String id;
}

class MainDeleteDefinitionRequested extends MainEvent {
  const MainDeleteDefinitionRequested({required this.id, this.deleteData = false});

  final String id;
  final bool deleteData;
}

/// Expose or un-expose a managed service to the local network (LAN).
class MainExposeLanRequested extends MainEvent {
  const MainExposeLanRequested({required this.id, this.enabled = true});

  final String id;
  final bool enabled;
}

class MainTailscaleAuthLinkDetected extends MainEvent {
  const MainTailscaleAuthLinkDetected({required this.url});

  final String url;
}
