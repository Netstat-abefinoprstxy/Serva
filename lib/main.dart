import 'package:flutter/material.dart';

import 'app_feedback.dart';
import 'backend_launcher.dart';
import 'view/homepage.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await startBackendIfNeeded();

  runApp(const ServaApp());
}

class ServaApp extends StatelessWidget {
  const ServaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Serva',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: rootScaffoldMessengerKey,
      themeMode: ThemeMode.dark,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.deepPurple,
          brightness: Brightness.dark,
        ),
        brightness: Brightness.dark,
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}
