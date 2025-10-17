import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/bot.dart';
import '../../services/browser_bot_runner/browser_bot_runner.dart';
import '../components/bot_console.dart';

class BotDetailView extends StatefulWidget {
  final Bot bot;

  BotDetailView({super.key, required this.bot});

  @override
  State<BotDetailView> createState() => _BotDetailViewState();
}

class _BotDetailViewState extends State<BotDetailView> {
  late final BrowserBotRunner _runner;
  BrowserBotSession? _session;
  StreamSubscription<BotSandboxMessage>? _subscription;
  bool _isRunning = false;
  final List<BotSandboxMessage> _consoleMessages = [];

  @override
  void initState() {
    super.initState();
    _runner = createBrowserBotRunner();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _session?.terminate();
    _runner.dispose();
    super.dispose();
  }

  void _startBot() {
    _session?.terminate();
    _subscription?.cancel();
    _session = null;

    _clearConsole();

    if (!_runner.canRun(widget.bot)) {
      _appendMessage(BotSandboxMessage.system(
          'Questo bot non è compatibile con il runtime browser.'));
      return;
    }

    try {
      final session = _runner.run(widget.bot);
      _session = session;

      setState(() {
        _isRunning = true;
      });

      _subscription = session.messages.listen((event) {
        setState(() {
          _consoleMessages.add(event);
        });
      }, onError: (error) {
        setState(() {
          _consoleMessages
              .add(BotSandboxMessage.stderr(error.toString()));
          _isRunning = false;
        });
      }, onDone: () {
        if (mounted) {
          setState(() {
            _isRunning = false;
          });
        }
      });

      session.completed.whenComplete(() {
        if (mounted) {
          setState(() {
            _isRunning = false;
          });
        }
        _session = null;
        _subscription = null;
      });
    } catch (e) {
      setState(() {
        _consoleMessages
            .add(BotSandboxMessage.stderr('Errore di esecuzione: $e'));
        _isRunning = false;
      });
    }
  }

  void _stopBot() {
    _session?.terminate();
    _subscription?.cancel();
    _session = null;
    setState(() {
      _isRunning = false;
      _consoleMessages
          .add(BotSandboxMessage.system('Esecuzione interrotta manualmente.'));
    });
  }

  void _clearConsole() {
    setState(() {
      _consoleMessages.clear();
    });
  }

  void _appendMessage(BotSandboxMessage message) {
    setState(() {
      _consoleMessages.add(message);
    });
  }

  @override
  Widget build(BuildContext context) {
    final bot = widget.bot;
    final isBrowserCompatible = bot.isBrowserCompatible;

    return Scaffold(
      appBar: AppBar(
        title: Text(bot.botName),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                bot.botName,
                style: Theme.of(context)
                    .textTheme
                    .headlineMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                bot.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  Chip(
                    avatar: const Icon(Icons.code, size: 18),
                    label: Text(bot.language),
                  ),
                  Chip(
                    avatar: Icon(
                      isBrowserCompatible ? Icons.web : Icons.block,
                      size: 18,
                    ),
                    label: Text(isBrowserCompatible
                        ? 'Compatibile con browser'
                        : 'Solo runtime locale'),
                    backgroundColor:
                        isBrowserCompatible ? Colors.green.shade100 : null,
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isRunning ? null : _startBot,
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Esegui Bot'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _isRunning ? _stopBot : null,
                    icon: const Icon(Icons.stop),
                    label: const Text('Ferma'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.redAccent,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              BotConsole(
                messages: _consoleMessages,
                onClear: _consoleMessages.isNotEmpty ? _clearConsole : null,
              ),
            ],
          ),
        ),
      ),
    );
  }
}