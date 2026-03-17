import 'dart:io';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;

import 'view/homepage.dart';

Process? _backendProcess;

/// Starts sovereignd.exe if it's not already running
Future<void> _startBackendIfNeeded() async {
  const port = 5055;

  // Simple health check first
  try {
    final request = await HttpClient().getUrl(
      Uri.parse('http://127.0.0.1:$port/health'),
    );
    final response = await request.close();
    if (response.statusCode == 200) {
      // Already running
      return;
    }
  } catch (_) {
    // Not running, continue to start it
  }

  final exeDir = File(Platform.resolvedExecutable).parent.path;
  final backendPath = p.join(exeDir, 'sovereignd.exe');

  if (!File(backendPath).existsSync()) {
    throw Exception('Backend not found at $backendPath');
  }

  _backendProcess = await Process.start(
    backendPath,
    ['--port', '$port'], // remove if your Go app doesn't use args
    mode: ProcessStartMode.detachedWithStdio,
    workingDirectory: exeDir,
  );

  // Optional logging during development
  _backendProcess!.stdout.transform(SystemEncoding().decoder).listen(print);
  _backendProcess!.stderr.transform(SystemEncoding().decoder).listen(print);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await _startBackendIfNeeded();

  runApp(const SovereignApp());
}

class SovereignApp extends StatelessWidget {
  const SovereignApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Sovereign',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
