import 'dart:async';
import 'package:flutter/material.dart';

import 'frontend/widgets/layout/home_shell.dart';
import 'frontend/widgets/pages/home_page_view.dart';
import 'frontend/widgets/pages/portfolio_view.dart';
import 'frontend/widgets/pages/bot_list_view.dart';
import 'frontend/widgets/pages/test1.dart';
import 'frontend/widgets/pages/test2.dart';
import 'frontend/widgets/pages/test3.dart';
import 'frontend/widgets/pages/settings_page.dart';
import 'frontend/widgets/pages/tutorial_page.dart';
import 'shared/custom_logger.dart';
import 'shared/services/telemetry_service.dart';
import 'backend/setup/backend_initializer_desktop.dart'
    if (dart.library.html) 'backend/setup/backend_initializer_web.dart'
        as backend_initializer;
import 'shared/platform/window_configuration_desktop.dart'
    if (dart.library.html) 'shared/platform/window_configuration_stub.dart'
        as window_configuration;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final logger = CustomLogger();
  final telemetryService = TelemetryService();
  await telemetryService.initialize();

  await backend_initializer.initializeBackend(logger, telemetryService);
  await window_configuration.configureWindow();

  runApp(MyApp(telemetryService: telemetryService));
}

class MyApp extends StatelessWidget {
  final TelemetryService telemetryService;

  const MyApp({super.key, required this.telemetryService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/home': (_) => const HomePage(),
        '/portfolio': (_) => Portfolio(),
        '/bots': (_) => BotList(),
        '/test1': (_) => test1(),
        '/test2': (_) => test2(),
        '/test3': (_) => test3(),
        '/settings': (_) => SettingsPage(telemetryService: telemetryService),
        '/tutorial': (_) => const TutorialPage(),
      },
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: const HomeShell(),
    );
  }
}