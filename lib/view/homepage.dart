import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sovereign/api/sovereign_api.dart';

import '../bloc/main_bloc.dart';
import 'homescreen.dart';

/// App entry point for the "home" experience.
///
/// Keep this widget intentionally boring:
/// - wires up the main BLoC
/// - renders the HomeScreen UI
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<MainBloc>(
      create: (_) => MainBloc(api: SovereignApi()),
      child: const HomeScreen(),
    );
  }
}
