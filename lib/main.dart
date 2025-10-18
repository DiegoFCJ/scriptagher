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
import 'shared/theme/theme_controller.dart';
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
  final themeController = ThemeController();
  await telemetryService.initialize();
  await themeController.initialize();

  await backend_initializer.initializeBackend(logger, telemetryService);
  await window_configuration.configureWindow();

  runApp(
    MyApp(
      telemetryService: telemetryService,
      themeController: themeController,
    ),
  );
}

class MyApp extends StatelessWidget {
  final TelemetryService telemetryService;
  final ThemeController themeController;

  MyApp({
    super.key,
    required this.telemetryService,
    ThemeController? themeController,
  }) : themeController = themeController ?? ThemeController();

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: themeController,
      builder: (context, _) {
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
          theme: themeController.themeData,
          home: const HomeShell(),
        );
      },
    );
  }
}
