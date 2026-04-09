import 'dart:io';

import 'package:flutter/foundation.dart';

enum BackendLaunchStatus {
  alreadyRunning,
  started,
  notFound,
  failed,
  skippedInDebug,
}

class BackendLaunchResult {
  const BackendLaunchResult({
    required this.status,
    this.message,
    this.backendPath,
  });

  final BackendLaunchStatus status;
  final String? message;
  final String? backendPath;

  bool get didRecover =>
      status == BackendLaunchStatus.alreadyRunning ||
      status == BackendLaunchStatus.started;
}

Process? _backendProcess;

bool looksLikeBackendUnavailableError(Object error) {
  final normalized = error.toString().toLowerCase();
  return normalized.contains('connection refused') ||
      normalized.contains('actively refused') ||
      normalized.contains('failed host lookup') ||
      normalized.contains('socketexception') ||
      (normalized.contains('health check failed') &&
          !normalized.contains('docker unavailable'));
}

Future<BackendLaunchResult> startBackendIfNeeded({
  bool allowInDebug = false,
}) async {
  const port = 8080;

  if (kDebugMode && !allowInDebug) {
    debugPrint('Debug mode detected; skipping sovereignd.exe auto-start.');
    return const BackendLaunchResult(
      status: BackendLaunchStatus.skippedInDebug,
      message: 'Debug mode skips automatic backend launch.',
    );
  }

  if (await _isBackendHealthy(port)) {
    return const BackendLaunchResult(
      status: BackendLaunchStatus.alreadyRunning,
    );
  }

  final backendPath = _findBackendExecutablePath();
  if (backendPath == null) {
    return const BackendLaunchResult(
      status: BackendLaunchStatus.notFound,
      message: 'Could not find sovereignd.exe.',
    );
  }

  try {
    final backendDir = File(backendPath).parent.path;
    _backendProcess = await Process.start(
      backendPath,
      const [],
      mode: ProcessStartMode.detachedWithStdio,
      workingDirectory: backendDir,
    );
  } on ProcessException catch (error) {
    debugPrint('Failed to start sovereignd.exe: $error');
    return BackendLaunchResult(
      status: BackendLaunchStatus.failed,
      message: error.toString(),
      backendPath: backendPath,
    );
  }

  _backendProcess!.stdout.transform(SystemEncoding().decoder).listen(print);
  _backendProcess!.stderr.transform(SystemEncoding().decoder).listen(print);

  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(const Duration(milliseconds: 300));
    if (await _isBackendHealthy(port)) {
      return BackendLaunchResult(
        status: BackendLaunchStatus.started,
        backendPath: backendPath,
      );
    }
  }

  return BackendLaunchResult(
    status: BackendLaunchStatus.failed,
    message: 'Started $backendPath, but /health never became ready.',
    backendPath: backendPath,
  );
}

Future<bool> _isBackendHealthy(int port) async {
  try {
    final request = await HttpClient().getUrl(
      Uri.parse('http://127.0.0.1:$port/health'),
    );
    final response = await request.close();
    return response.statusCode == 200;
  } catch (_) {
    return false;
  }
}

String? _findBackendExecutablePath() {
  final candidates = <String>{
    '${File(Platform.resolvedExecutable).parent.path}${Platform.pathSeparator}sovereignd.exe',
    '${Directory.current.path}${Platform.pathSeparator}backend${Platform.pathSeparator}sovereignd${Platform.pathSeparator}sovereignd.exe',
    '${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}runner${Platform.pathSeparator}Debug${Platform.pathSeparator}sovereignd.exe',
    '${Directory.current.path}${Platform.pathSeparator}build${Platform.pathSeparator}windows${Platform.pathSeparator}x64${Platform.pathSeparator}runner${Platform.pathSeparator}Release${Platform.pathSeparator}sovereignd.exe',
  };

  for (final path in candidates) {
    if (File(path).existsSync()) {
      return path;
    }
  }

  return null;
}
