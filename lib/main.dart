import 'dart:async';
import 'package:flutter/material.dart';
import 'shared/custom_logger.dart';
import 'backend/server/server.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:scriptagher/shared/constants/LOGS.dart';
import 'backend/server/db/bot_database.dart';
import 'package:bitsdojo_window/bitsdojo_window.dart';
import 'package:scriptagher/frontend/widgets/components/window_title_bar.dart';
import 'package:scriptagher/frontend/widgets/pages/home_page_view.dart';
import 'package:scriptagher/frontend/widgets/pages/portfolio_view.dart';
import 'package:scriptagher/frontend/widgets/pages/bot_list_view.dart';
import 'package:scriptagher/frontend/widgets/pages/test1.dart';
import 'package:scriptagher/frontend/widgets/pages/test2.dart';
import 'package:scriptagher/frontend/widgets/pages/test3.dart';
import 'package:scriptagher/frontend/widgets/pages/settings_page.dart';
import 'package:scriptagher/frontend/widgets/pages/tutorial_page.dart';
import 'package:scriptagher/shared/services/telemetry_service.dart';


// La tua vista principale di Flutter
Future<void> main() async {
  // Inizializza il binding di Flutter
  WidgetsFlutterBinding.ensureInitialized();

  // Crea un'istanza del CustomLogger
  final CustomLogger logger = CustomLogger();
  final telemetryService = TelemetryService();
  await telemetryService.initialize();

  await startDB(logger);
  // Avvio del backend
  await startBackend(logger, telemetryService);

// Configura la finestra prima dell'avvio dell'app
  doWhenWindowReady(() {
    final win = appWindow;
    win.minSize = const Size(800, 600); // Imposta una dimensione minima
    win.size = const Size(1024, 768); // Imposta una dimensione iniziale
    win.alignment = Alignment.center;
    win.title = "Scriptagher"; // Titolo della finestra
    win.show(); // Mostra la finestra
  });
  
  // Avvio del frontend
  runApp(MyApp(telemetryService: telemetryService));
}

Future<void> startDB(CustomLogger logger) async {
  // Inizializza il databaseFactory per sqflite_common_ffi
  databaseFactory = databaseFactoryFfi;

  final botDatabase = BotDatabase();

  // Inizializza il database (chiamando il getter della database)
  try {
    logger.info(LOGS.serverStart, 'Attempting to initialize database...');
    await botDatabase.database;
    logger.info(LOGS.serverStart, 'Database initialized successfully');
  } catch (e) {
    logger.error(LOGS.serverError, 'Error initializing database: $e');
    return; // Fermare l'avvio del server in caso di errore nel database
  }
}

// Funzione per avviare il backend
Future<void> startBackend(
    CustomLogger logger, TelemetryService telemetryService) async {
  try {
    // Log di avvio del backend
    logger.info('Avvio del server...', 'Avvio del backend');
    await startServer(); // Qui dovrai avviare il server vero e proprio
    logger.info('Server avviato con successo', 'Avvio del backend');
  } catch (e) {
    logger.error(
        'Errore durante l\'avvio del server: $e', 'Errore nel backend');
    await telemetryService.recordExecutionFailure(
      reason: 'backend_start_failure',
      extra: {
        'error_type': e.runtimeType.toString(),
      },
    );
  }
}

// Avvio dell'app principale
class MyApp extends StatelessWidget {
  final TelemetryService telemetryService;

  const MyApp({super.key, required this.telemetryService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(

      routes: {
        '/home':     (_) => HomePage(),       // la tua HomePage con il carosello
        '/portfolio':(_) => Portfolio(),  // la pagina Portfolio
        '/bots':     (_) => BotList(),   // la pagina Bots List
        '/test1':     (_) => test1(),   // la pagina Bots List
        '/test2':     (_) => test2(),   // la pagina test1 List
        '/test3':     (_) => test3(),   // la pagina test1 List
        '/settings': (_) => SettingsPage(telemetryService: telemetryService),
        '/tutorial': (_) => const TutorialPage(),
      },

      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.blue),
      home: WindowBorder(
        child: HomeScreen(),
        color: Colors.transparent,
      ),
    );
  }
}

class HomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        WindowTitleBar(),
        Expanded(
          child: HomePage(),
        ),
      ],
    );
  }
}